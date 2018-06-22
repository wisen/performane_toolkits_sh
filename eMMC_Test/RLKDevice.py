import os
import subprocess
import RLKThread
import RLKDB
import threading
import time
import datetime
import re
import random

import numpy as np
import plotly.offline as py
import plotly.graph_objs as go
import matplotlib.pyplot as plt
from matplotlib import animation
import json
import configparser as cp
import Util as u

import Debug as d

class RLKDevice():

	def __init__(self, dev_sn, db, offline=False):
		self.dev_sn = dev_sn
		d.init()

		if offline:
			self.dminx = "0"
			self.db = db
			self.db.connect()
			self.cmd = "select * from deviceinfo order by stime desc limit 1"
			buf = self.db.fetch(self.cmd)
			self.storage = buf[0][1]
			self.ratio = buf[0][2]
			self.segment = json.loads(buf[0][4].replace("'", "\""))
			self.db.commit()
		else:
			self.ini_file = "conf/" + self.dev_sn + ".ini"
			self.load_config()

			self.db = db
			self.monthread = "on"

			self.db.connect()
			self.db.create_table('''
				create table IF NOT EXISTS deviceinfo
				(sn text, df float, ratio float, stime datetime, seginfo text)
				''')
			self.cmd = "insert into deviceinfo(sn, df, ratio, stime, seginfo) values(?,?,?,?,?)"
			self.db.commit()
			self.has_wring = False
			self.has_deling = False
			self.has_moning = False
			self.status = "online"
			self.ratio = 0.0
			self.segment = {"0":0, "512":0, "z":[]}
			self.dminx = "0"
			self.query_dminx()

	def load_config(self):
		if not os.path.exists(self.ini_file):
			u.copyfile("conf/global.ini", self.ini_file)
		self.parse_ini_file(self.ini_file)

	def parse_ini_file(self, ini_file):
		self.active_ini = cp.ConfigParser()
		self.active_ini.read(ini_file)
		self.active_ini_filename = ini_file
		#for key in self.active_ini["SETTING"]:
		#	print(key+" "+self.active_ini["SETTING"][key])
		self.wrthreads = int(self.active_ini["SETTING"]["wrthreads"])
		self.wrdelay = int(self.active_ini["SETTING"]["wrdelay"])
		self.delthreads = int(self.active_ini["SETTING"]["delthreads"])
		self.deldelay = int(self.active_ini["SETTING"]["deldelay"])
		self.mondelay = int(self.active_ini["SETTING"]["mondelay"])
		self.detdelay = int(self.active_ini["SETTING"]["detdelay"])
		self.path = self.active_ini["SETTING"]["path"]
		self.dir = self.active_ini["SETTING"]["dir"]
		self.stop_wr = float(self.active_ini["SETTING"]["stop_wr"])
		self.stop_del = float(self.active_ini["SETTING"]["stop_del"])
		self.sleeptime = int(self.active_ini["SETTING"]["sleeptime"])

	def destroy(self):
		self.db.commit()
		self.db.close()
	
	# unauthorized offline device
	def status_str(self, str):
		if "device" == str:
			return "online"
		else:
			return str
			
	def detect(self, dev_sn, path):
		cmd = ["adb", "-s", self.dev_sn, "devices"]
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		tmp_dev = []
		i = 0
		while True:
			line = proc.stdout.readline().strip()
			if len(line) is not 0:
				if line[0:4] == b'List' or line[0:1] == b'*':
					continue
				else:
					self.status = self.status_str(bytes.decode(line.split()[1]))
					break
			else:
				self.status = "offline"
				break
					
		if self.status != "online":
			if self.has_moning:
				self.stop_monthread()
		return

	def stop_detectthread(self):
		d.d("stopping "+self.dev_sn+"-detect-0")
		self.detect_stopevt.set()
		return
					
	def start_detectthread(self):
		d.d("starting "+self.dev_sn+"-detect-0")
		self.detect_stopevt = threading.Event()
		t=RLKThread.RLKThread(stopevt=self.detect_stopevt, name=self.dev_sn+"-detect-0", target=self.detect, args=self.dev_sn, kwargs={}, delay=self.detdelay)
		t.start()
					
	def query_dminx(self):
		cmd = ["adb", "-s", self.dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[0])[-1]
		self.dminx = cmd_out

		return self.dminx

	def query_storage(self):
		cmd = ["adb", "-s", self.dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[4])
		self.storage = float(cmd_out.strip('%'))/100
		return self.storage

	def query_fragment(self):
		ratio = self.calc_fragment_ratio()
		self.frag = float('%.2f' % ratio)
		return

	## storage the info each one minute
	def store_deviceinfo(self):
		self.query_storage()
		self.query_fragment()
		self.db.execute(self.cmd, (self.dev_sn, self.storage, self.ratio, datetime.datetime.now(), str(self.segment)))
		self.db.commit()
		return
		
	def update_status(self, status):
		self.status = status

	def stop_wrthreads(self):
		d.d("stopping wrthreads.....")
		self.has_wring = False
		self.wr_stopevt.set()
		return
	
	def start_wrthreads(self):
		d.d("starting wrthreads.....")
		self.wr_stopevt = threading.Event()
		self.has_wring = True
		for i in range(self.wrthreads):
			t=RLKThread.RLKThread(stopevt=self.wr_stopevt, name=self.dev_sn+"-wr-"+str(i), target=self.write, args=self.dev_sn, kwargs={"path":self.path+self.dir+str(i)}, delay=self.wrdelay)
			t.start()
	
	def write(self,dev_sn,path):
		cmd_str="if [ ! -f "+path["path"]+" ];then mkdir -p "+path["path"]+";fi;"+"_tmp_size=$(($RANDOM%99+1));dd if=/dev/urandom of="+path["path"]+"/$(($RANDOM*1000+$RANDOM))_${_tmp_size}k.dat bs=${_tmp_size}k count=1;sync;"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]

		try:
			proc = subprocess.run(cmd, shell=False)
		except OSError as e:
			print(e)	
		return

	def stop_delthreads(self):
		d.d("stopping delthreads.....")
		self.has_deling = False
		self.del_stopevt.set()
		return
	
	def start_delthreads(self):
		d.d("starting delthreads.....")
		self.del_stopevt = threading.Event()
		self.has_deling = True
		for i in range(self.delthreads):
			j = random.randint(1,self.wrthreads)
			t=RLKThread.RLKThread(stopevt=self.del_stopevt, name=self.dev_sn+"-del-"+str(i), target=self.delete, args=self.dev_sn, kwargs={"path":self.path+self.dir+str(j)}, delay=self.deldelay)
			t.start()	

	def delete(self,dev_sn,path):
		cmd_str="rm -rf "+path["path"]+"/*_$(($RANDOM%99+1))k.dat;sync"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]
		try:
			proc = subprocess.call(cmd, shell=False)
		except OSError as e:
			print(e)
		
		return

	def stop_monthread(self):
		self.has_moning = False
		self.mon_stopevt.set()
		if self.has_wring:
			self.stop_wrthreads()
		
		if self.has_deling:
			self.stop_delthreads()	
		return
	
	def start_monthread(self):
		d.d("starting monthread.....")
		self.mon_stopevt = threading.Event()
		self.has_moning = True
		t=RLKThread.RLKThread(stopevt=self.mon_stopevt, name=self.dev_sn+"-mon-0", target=self.monitor, args=self.dev_sn, kwargs={}, delay=self.mondelay)
		t.start()

	## monitor thread will monitor when device should write, when should delete
	def monitor(self,dev_sn, path):
		#print("monitor func on device:"+self.dev_sn)
		df = self.query_storage()
		if df > self.stop_wr:
			if self.has_wring:
				self.stop_wrthreads()
				
			if not self.has_deling:
				self.start_delthreads()		
		if df < self.stop_del:
			if self.has_deling:
				self.stop_delthreads()
				
			if not self.has_wring:
				self.start_wrthreads()

		self.store_deviceinfo()
		return

	def adjust_value(self, v):
		if (v > 0) and (v < 512):
			return 256

		return v

	def parse_info(self, line):
		ret = re.split(r'\d\|',line)
		if ret is None:
			return None

		if len(ret) == 1:
			return None

		info = ret[1:]
		l = len(info)

		z=[]
		cnt_0 = 0
		cnt_512 = 0
		for i in range(l):
			if int(info[i]) == 0:
				cnt_0 += 1
			if int(info[i]) == 512:
				cnt_512 += 1
			k = int(info[i])
			z.append(k)

		return {"0":cnt_0, "512":cnt_512, "z":z}

	def calc_fragment_ratio(self):
		self.segment= {"0":0, "512":0, "z":[]}
		
		path = "/proc/fs/f2fs/dm-"+self.dminx+"/segment_info"
		cmd = ["adb", "-s", self.dev_sn, "shell", "cat", path]
		d.d("["+self.dev_sn+"]: calc_fragment_ratio....")
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None

		while True:
			line = proc.stdout.readline().strip()
			if len(line) is 0:
				break
			try:
				line = str(line, encoding = "utf-8")
			except UnicodeDecodeError as e:
				print(e)
				continue

			info = self.parse_info(line)
			if info is not None:
				self.segment["0"] += info["0"]
				self.segment["512"] += info["512"]
				self.segment["z"] += info["z"]
		self.ratio = (len(self.segment["z"])-self.segment["0"]-self.segment["512"])/len(self.segment["z"])
		self.update_segment()
		return self.ratio

	def update_segment(self):
		cnt = len(self.segment["z"])
		dy1 = 100
		dx1 = int(cnt / dy1) + 1
		i = 0
		dcnt = dx1 * dy1
		if (dcnt > cnt):
			for i in range(cnt, dcnt):
				self.segment["z"].append(999)

	def draw_fragment_heatmap_byplotly(self):  ##use plotly
		dy1 = 100
		dx1 = int(len(self.segment["z"]) / dy1)

		bb = []
		bb = np.array(self.segment["z"]).reshape(dx1, dy1)

		xa = np.array(range(dx1))
		ya = np.array(range(dy1))
		trace = go.Heatmap(
			x=xa,
			y=ya[::-1],
			z=bb,
			# colorscale='Viridis',
			colorscale='Jet',
		)
		data = [trace]

		layout = go.Layout(
			title="["+self.dev_sn+"]: "+str(self.storage)+" "+str(float('%.2f' % self.ratio)),
			xaxis=dict(title="segment row"),
			yaxis=dict(title="segment col"),
		)

		fig = go.Figure(data=data, layout=layout)
		output_filename = "f2fs_fragment_v2_" + self.dev_sn + ".html"
		py.plot(fig, filename=output_filename)

	def draw_both_bytime(self):
		sel_cmd = "select df,ratio from deviceinfo"
		buf = self.db.fetch(sel_cmd)
		cnt = len(buf)
		fig = plt.figure()
		a = []
		b = []
		for i in range(cnt):
			a.append(buf[i][0])
			b.append(buf[i][1])
		line1 = plt.plot(a)
		line2 = plt.plot(b)
		title = "["+self.dev_sn+"]: "+str(self.storage)+" "+str(float('%.2f' % self.ratio))
		plt.title(title)
		plt.show()

	def draw_fragment_ratio_bytime(self):
		sel_cmd = "select ratio from deviceinfo"
		buf = self.db.fetch(sel_cmd)
		fig = plt.figure()
		line = plt.plot(buf)[0]
		line.set_color('r')
		title = "["+self.dev_sn+"]: "+str(self.storage)+" "+str(float('%.2f' % self.ratio))
		plt.title(title)
		plt.show()

	def draw_fragment_heatmap_animation(self):
		sel_cmd = "select seginfo from deviceinfo"
		buf = self.db.fetch(sel_cmd)
		cnt = len(buf)
		dy1 = 100
		fig = plt.figure()
		#fig, ax = plt.subplots()
		ims = []

		if cnt > 100:
			step=int(cnt/100)+1
			for i in range(0, cnt, step):
				bb = buf[i]
				cc = json.loads(bb[0].replace("'", "\""))["z"]
				dx1 = int(len(cc) / dy1)
				dd = np.array(cc).reshape(dx1,dy1)
				ims.append((plt.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), dd, norm=plt.Normalize(0, 999)),))
		else:
			for i in range(cnt):
				bb = buf[i]
				cc = json.loads(bb[0].replace("'", "\""))["z"]
				dx1 = int(len(cc) / dy1)
				dd = np.array(cc).reshape(dx1,dy1)
				ims.append((plt.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), dd, norm=plt.Normalize(0, 999)),))

		#fig.colorbar(ims)
		im_ani = animation.ArtistAnimation(fig, ims, interval=500, repeat_delay=1000,blit=True)
		plt.show()
		return

	def draw_fragment_heatmap_bymatplot(self):##use matplotlib

		dy1 = 100
		dx1 = int(len(self.segment["z"])/dy1)

		bb = []
		bb = np.array(self.segment["z"]).reshape(dx1,dy1)

		fig, ax = plt.subplots()
		im = ax.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), bb, norm=plt.Normalize(0, 999))
		fig.colorbar(im)
		title = "["+self.dev_sn+"]: "+str(self.storage)+" "+str(float('%.2f' % self.ratio))
		plt.title(title)

		plt.show()
		
def testDevices():
	db = RLKDB.RLKDB("./test1.db")
	dev = RLKDevice("FA7841800628", db)
	#dev.start_wrthreads()
	dev.start_detectthread()
	print(threading.enumerate())
	time.sleep(5)
	print(repr(threading.currentThread())+'send stop signal\n')
	#dev.stop_wrthreads()
	dev.stop_detectthread()
	#print(dev.detect())
	#print(dev.query_dminx())
	#print(dev.query_storage())

if __name__ == "__main__":
	testDevices()