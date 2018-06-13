import os
import subprocess
import RLKThread
import RLKDB
import threading
import time
import datetime
import re

import numpy as np
import pandas as pd
import plotly.offline as py
import plotly.graph_objs as go

class RLKDevice():

	def __init__(self, dev_sn, db):
		self.dev_sn = dev_sn
		##colnums:  sn,status,df,frag,stime,stoptime,seginfo
		self.db = db
		self.wrthreads = 3
		self.wrdelay = 2 ## should set to 0 in final release
		self.delthreads = 5
		self.deldelay = 2 ## should set to 0 in final release
		self.mondelay = 5 ## we should monitor the device's storage and fragment status per 5 seconds
		self.detdelay = 2
		self.path = "/sdcard/tmp/"
		self.dir = "dir"
		self.stop_wr = 0.95
		self.stop_del = 0.90
		self.sleeptime = 10
		self.monthread = "on"
		self.dminx = "0"
		self.db.connect()
		self.db.create_table('''
			create table IF NOT EXISTS deviceinfo
			(sn text, df text, ratio float, stime datetime, seginfo text)
			''')
		self.cmd = "insert into deviceinfo(sn, df, ratio, stime, seginfo) values(?,?,?,?,?)"

		self.db.commit()
		self.has_wring = False
		self.has_deling = False
		self.has_moning = False
		self.status = "online"
		self.ratio = 0.0
		self.segment = {"0":0, "512":0, "z":[]}
		self.query_dminx()
	
	def destroy():
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
			print("device offline")
			if self.has_moning:
				self.stop_monthread()
		return

	def stop_detectthread(self):
		print("stop_detectthread.....")
		self.detect_stopevt.set()
		return
					
	def start_detectthread(self):
		print("start_detectthread.....")
		self.detect_stopevt = threading.Event()
		t=RLKThread.RLKThread(stopevt=self.detect_stopevt, name=self.dev_sn+"-detect-0", target=self.detect, args=self.dev_sn, kwargs={}, delay=self.detdelay)
		t.start()
					
	def query_dminx(self):
		cmd = ["adb", "-s", self.dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		#print("query_dm_inx:"+" ".join(cmd))
		try:
			#proc = subprocess.call(cmd, shell=False)
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[0])[-1]
		self.dminx = cmd_out
		return self.dminx

	def query_storage(self):
		#adb shell df -h | grep "/dev/block/dm-" | grep "\/data" | awk '{print $5}'
		cmd = ["adb", "-s", self.dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		#print("query_device_storage:"+" ".join(cmd))
		try:
			#proc = subprocess.call(cmd, shell=False)
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[4])
		self.storage = cmd_out
		return self.storage

	def query_fragment(self):
		ratio = self.calc_fragment_ratio()
		self.frag = float('%.2f' % ratio)
		return

	## storage the info each one minute
	def store_deviceinfo(self):
		self.query_storage()
		self.query_fragment()
		#sn text, df text, ratio float, stime datetime, seginfo text
		self.db.execute(self.cmd, (self.dev_sn, self.storage, self.ratio, datetime.datetime.now(), str(self.segment)))
		#self.db.execute(self.cmd, (self.dev_sn, self.storage, self.ratio, self.segment))
		self.db.commit()
		return
		
	def update_status(self, status):
		self.status = status

	def stop_wrthreads(self):
		print("stop_wrthreads.....")
		self.has_wring = False
		self.wr_stopevt.set()
		return
	
	def start_wrthreads(self):
		print("start_wrthreads.....")
		self.wr_stopevt = threading.Event()
		self.has_wring = True
		for i in range(self.wrthreads):
		#print(i)
			t=RLKThread.RLKThread(stopevt=self.wr_stopevt, name=self.dev_sn+"-wr-"+str(i), target=self.write, args=self.dev_sn, kwargs={"path":self.path+self.dir+str(i)}, delay=self.wrdelay)
			t.start()
	
	def write(self,dev_sn,path):
		cmd_str="if [ ! -f "+path["path"]+" ];then mkdir -p "+path["path"]+";fi;"+"_tmp_size=$(($RANDOM%99+1));dd if=/dev/urandom of="+path["path"]+"/$(($RANDOM*1000+$RANDOM))_${_tmp_size}k.dat bs=${_tmp_size}k count=1 status=none;sync;"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]

		#print(cmd_str)
		#print(cmd)
		try:
			proc = subprocess.run(cmd, shell=False)
		except OSError as e:
			print(e)	
		return

	def stop_delthreads(self):
		self.has_deling = False
		self.del_stopevt.set()
		return
	
	def start_delthreads(self):
		self.del_stopevt = threading.Event()
		self.has_deling = True
		for i in range(self.delthreads):
		#print(i)
			i = random.randint(1,self.wrthreads)
			t=RLKThread.RLKThread(stopevt=self.del_stopevt, name=self.dev_sn+"-del-"+str(i), target=self.delete, args=self.dev_sn, kwargs={"path":self.path+self.dir+str(i)}, delay=self.deldelay)
			t.start()	

	def delete(self,dev_sn,path):
		#cmd_str="while [ 1 ];do file_list=`ls "+path+"/*k.dat`;j=0;for file in $file_list;do rm -f $file;j=`expr $j + 1`;echo '$j: delete "+path+"/$file';if [ $j -gt 10 ];then break;fi;done;sync;exit;done"
		cmd_str="rm -rf "+self.path["path"]+self.dir+"$(($RANDOM%99+1))/*_$(($RANDOM%99+1))k.dat status=none;sync"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]
		#print(cmd_str)
		#print(cmd)
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
		self.mon_stopevt = threading.Event()
		self.has_moning = True
		t=RLKThread.RLKThread(stopevt=self.mon_stopevt, name=self.dev_sn+"-mon-0", target=self.monitor, args=self.dev_sn, kwargs={}, delay=self.mondelay)
		t.start()

	## monitor thread will monitor when device should write, when should delete
	def monitor(self,dev_sn, path):
		print("monitor func on device:"+self.dev_sn)
		df = self.query_storage()
		if float(df.strip('%')) > self.stop_wr*100:
			if self.has_wring:
				self.stop_wrthreads()
				
			if not self.has_deling:
				self.start_delthreads()		
		if float(df.strip('%')) < self.stop_del*100:
			if self.has_deling:
				self.stop_delthreads()
				
			if not self.has_wring:
				self.start_wrthreads()	
		print(threading.enumerate())
		print("storage into db.....")
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

		#index = ret[0].strip()
		info = ret[1:]
		l = len(info)
		#print(l)

		#x=[]
		#y=[]
		z=[]
		cnt_0 = 0
		cnt_512 = 0
		for i in range(l):
			#x.append(int(i))
			#y.append(int(index))
			#print(info[i])
			if int(info[i]) == 0:
				cnt_0 += 1
			if int(info[i]) == 512:
				cnt_512 += 1
			#k = self.adjust_value(int(info[i]))
			k = int(info[i])
			z.append(k)

		#print(z)
		return {"0":cnt_0, "512":cnt_512, "z":z}

	def calc_fragment_ratio(self):
		#segment= {"0":0, "512":0, "z":[]}
		self.segment["z"] = []
		self.segment["0"] = 0
		self.segment["512"] = 0
		
		path = "/proc/fs/f2fs/dm-"+self.dminx+"/segment_info"
		cmd = ["adb", "-s", self.dev_sn, "shell", "cat", path]
		print("calc_fragment_ratio:"+" ".join(cmd))
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
				#print(line)
			except UnicodeDecodeError as e:
				print(e)
				continue

			info = self.parse_info(line)
			#print(info)
			if info is not None:
				self.segment["0"] += info["0"]
				self.segment["512"] += info["512"]
				self.segment["z"] += info["z"]
				#segment += info
		#print(segment)
		self.ratio = (len(self.segment["z"])-self.segment["0"]-self.segment["512"])/len(self.segment["z"])
		return self.ratio

	def draw_fragment_heatmap(self):
		aa = []
		cnt = 0
		for line in self.segment["z"]:
			x = int(line)
			if(x>0) and (x<512):
				x=256
			aa.append(x)
			cnt=cnt+1
		
		dy1 = 100
		dx1 = int(cnt/dy1) + 1
		i=0
		dcnt=dx1*dy1
		if(dcnt>cnt):
			for i in range(cnt,dcnt):
				aa.append(int(999))

		bb = []
		bb = np.array(aa).reshape(dx1,dy1)

		xa = np.array(range(dx1))
		ya = np.array(range(dy1))
		trace = go.Heatmap(
					x=xa,
					y=ya[::-1],
					z=bb,
					#colorscale='Viridis',
					colorscale='Jet',
					)
		data=[trace]

		layout = go.Layout(
			title="["+self.dev_sn+"] frag info: ["+self.storage+"] "+str(float('%.2f' % self.ratio)),
			#height = (len(segment["z"])//10)*8,
			xaxis = dict(title = "segment row"),
			yaxis = dict(title = "segment col"),
		)

		fig = go.Figure(data=data, layout=layout)
		output_filename="f2fs_fragment_v2_"+self.dev_sn+".html"
		py.plot(fig,filename=output_filename)
		
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