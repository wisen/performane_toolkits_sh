#!/usr/bin/env python 

import os
import math
import subprocess
import datetime
import time
import re
import random
import threading

from tkinter import messagebox as mBox
from tkinter import *
from tkinter import ttk
from tkinter import scrolledtext
	
import numpy as np
import pandas as pd
import plotly.offline as py
import plotly.graph_objs as go

class FragmentUI:

	def __init__(self,name):
		self.name = name
		self.devices = {}
		self.wrthreads = 10
		self.delthreads = 5
		self.path = "/sdcard/tmp/"
		self.dir = "dir"
		self.stop_wr = 0.95
		self.stop_del = 0.90
		self.sleeptime = 10
		self.monthread = "on"
		## dminx ==> dm-0
		self.dminx = "0"

	def window_cloe(self):
		self.stop_all()
		self.ui.destroy()
		print("close windows....")
		return

	def _quit(self):
		self.window_cloe()
	
	def pop(self,event):
		self.popmenuBar.post(event.x_root,event.y_root)

	def No_Select(self):
		mBox.showinfo('Alert', "Please select a device!!!")
		return
		
	def draw_fragment(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.calc_fragment_ratio(dev_sn, True)
			return
		
	def init_ui(self,listitems):
		root = Tk()
		root.title("Fragment tools V1.0")
		root.geometry("720x400")
		root.resizable(width=False, height=False)
		self.root = root
		
		s = ttk.Style()
		s.theme_use('classic')

		menuBar = Menu(root, font=("Monospace Regular",16))
		root.config(menu=menuBar)
		fileMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="File", menu=fileMenu)
		fileMenu.add_command(label="New", font=("Monospace Regular",16))
		#fileMenu.add_command(label="Exit")
		fileMenu.add_separator()
		fileMenu.add_command(label="Exit", command=self._quit, font=("Monospace Regular",16))
		
		configMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Config", menu=configMenu)
		configMenu.add_command(label="Global", font=("Monospace Regular",16))
		
		helpMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Help", menu=helpMenu)
		helpMenu.add_command(label="About", font=("Monospace Regular",16))
		helpMenu.add_separator()
		helpMenu.add_command(label="Help", font=("Monospace Regular",16))
		
		frm = ttk.LabelFrame(root,text="Fragment tool V1.0").grid(column=0,row=0)

		## frm_devices start
		ttk.Label(text="choose a device", font=("Monospace Regular",16)).grid(column=0,row=0,columnspan=2)

		var = StringVar()
		lb_devices = Listbox(frm, font=("Monospace Regular",16), width=20, listvariable = var)
		lb_devices.grid(column=0,row=1,rowspan=2,columnspan=2)
		self.lb_devices = lb_devices
		#print(lb_devices)

		lb_devices.bind('<ButtonRelease-1>', self.init_item)
		list_item = listitems
		for item in list_item:
			lb_devices.insert(END, item)

		start_btn = ttk.Button(frm, text=">>>", command=self.start_func)
		start_btn.grid(column=2,row=1)
		stop_btn = ttk.Button(frm, text="<<<", command=self.stop_func)
		stop_btn.grid(column=2,row=2)
			
		ttk.Label(text="monitor devices", font=("Monospace Regular",16)).grid(column=3,row=0)
		var = StringVar()
		lb_monitors = Listbox(frm, font=("Monospace Regular",16), width=20, listvariable = var)
		lb_monitors.grid(column=3,row=1,rowspan=2)
		self.lb_monitors = lb_monitors

		lb_monitors.bind('<ButtonRelease-1>', self.monitor_item)

		## pop nume start
		popmenuBar = Menu(root, font=("Monospace Regular",16), tearoff=0)
		popmenuBar.add_command(label="show", command=self.draw_fragment)
		self.popmenuBar = popmenuBar
		lb_monitors.bind("<ButtonRelease-3>", self.pop)
		## pop menu end
		
		## frm_status start
		ttk.Label(text="device status", font=("Monospace Regular",16)).grid(column=4,row=0)
		scrolW = 30 # 设置文本框的长度
		scrolH = 13 # 设置文本框的高度
		scr = scrolledtext.ScrolledText(frm, width=scrolW, height=scrolH, wrap=WORD, font=("Monospace Regular",12)) 
		scr.grid(column=4, row=1, rowspan=2)
		self.scr = scr

		ttk.Label(text="wr threads:", font=("Monospace Regular",16)).grid(column=0,row=3)
		self.wrname = StringVar()
		wrnameEntered = ttk.Entry(frm, width=10, textvariable=self.wrname)
		wrnameEntered.grid(column=1, row=3)
		wrnameEntered.insert(10, self.wrthreads)
		wrnameEntered.focus()   
		
		ttk.Label(text="del threads:", font=("Monospace Regular",16)).grid(column=0,row=4)
		self.delname = StringVar()
		delnameEntered = ttk.Entry(frm, width=10, textvariable=self.delname)
		delnameEntered.insert(10, self.delthreads)
		delnameEntered.grid(column=1, row=4)
	
		ttk.Label(text="sleep time:", font=("Monospace Regular",16)).grid(column=0,row=5)
		self.sleepname = StringVar()
		sleepnameEntered = ttk.Entry(frm, width=10, textvariable=self.sleepname)
		sleepnameEntered.insert(10, self.sleeptime)
		sleepnameEntered.grid(column=1, row=5)
		
		ttk.Label(text="Max percent:", font=("Monospace Regular",16)).grid(column=0,row=6)
		self.maxname = StringVar()
		maxnameEntered = ttk.Entry(frm, width=10, textvariable=self.maxname)
		maxnameEntered.insert(10, self.stop_wr)
		maxnameEntered.grid(column=1, row=6) 
		
		ttk.Label(text="Min percent:", font=("Monospace Regular",16)).grid(column=0,row=7)
		self.minname = StringVar()
		minnameEntered = ttk.Entry(frm, width=10, textvariable=self.minname)
		minnameEntered.insert(10, self.stop_del)
		minnameEntered.grid(column=1, row=7) 
	
		update_config_btn = ttk.Button(frm, text="Update", command=self.update_config)
		update_config_btn.grid(column=1,row=8)		
						
		## UI loop start
		self.ui = root
		root.protocol("WM_DELETE_WINDOW", self.window_cloe)
		root.mainloop()

	def update_config(self):
		self.wrthreads = int(self.wrname.get())
		#print(self.wrthreads)
		self.delthreads = int(self.delname.get())
		#print(self.delthreads)
		self.sleeptime = int(self.sleepname.get())
		#print(self.sleeptime)
		self.stop_wr = float(self.maxname.get())
		self.stop_del = float(self.minname.get())
		#print(self)
		return
		
	def start_func(self):
		if len(self.lb_devices.curselection()) == 0:
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn]={"s":"online","df":0.0,"frag":0.0,"stime":datetime.datetime.now(),"wrfn":"on","delfn":"off"}
			self.lb_devices.delete(self.lb_devices.curselection())
			self.lb_monitors.insert(END, dev_sn)
			self.create_wr_thread(dev_sn)
			self.create_del_thread(dev_sn)
			self.create_monitor_thread()

	def stop_func(self):
		print("stop_func")
		print(len(self.lb_monitors.curselection()))
		if len(self.lb_monitors.curselection()) != 0:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn]["s"] = "offline"
			self.lb_monitors.delete(self.lb_monitors.curselection())
			self.lb_devices.insert(END, dev_sn)
			self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			print(self.devices)
		return
		
	def show_status(self, dev_sn):
		self.query_device_storage(dev_sn)
		self.query_device_fragment(dev_sn)
		print("print device["+dev_sn+ "]'s status")
		self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
		status_str="device["+dev_sn+"]: \n"
		status_str=status_str+"Status: "+self.devices[dev_sn]["s"]+"\n"
		status_str=status_str+"df: "+str(self.devices[dev_sn]["df"])+"\n"
		status_str=status_str+"frag: "+str(self.devices[dev_sn]["frag"])+"\n"
		status_str=status_str+"stime: "+self.devices[dev_sn]["stime"].strftime('%Y-%m-%d %H:%M:%S')+"\n"
		status_str=status_str+"write: "+str(self.devices[dev_sn]["wrfn"])+"\n"
		status_str=status_str+"delete: "+str(self.devices[dev_sn]["delfn"])+"\n"
		status_str=status_str+"\nGlobal config: \n"
		status_str=status_str+"write threads: "+str(self.wrthreads)+"\n"
		status_str=status_str+"del threads: "+str(self.delthreads)+"\n"
		status_str=status_str+"sleep time: "+str(self.sleeptime)+"\n"
		status_str=status_str+"Max percent: "+str(self.stop_wr*100)+"%\n"
		status_str=status_str+"Min percent: "+str(self.stop_del*100)+"%\n"
		self.scr.insert(END,status_str)		
	
	def init_item(self,event):
		if len(self.lb_devices.curselection()) == 0:
			return
		else:
			self.show_init_status()

	def query_dm_inx(self, dev_sn):
		cmd = ["adb", "-s", dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		print("query_dm_inx:"+" ".join(cmd))
		try:
			#proc = subprocess.call(cmd, shell=False)
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[0])[-1]
		self.dminx = cmd_out
		return
			
	def show_init_status(self):
		dev_sn=self.lb_devices.get(self.lb_devices.curselection())
		self.devices[dev_sn]={"s":"offline","df":0.0,"frag":0.0,"stime":datetime.datetime.now(),"wrfn":"off","delfn":"off"}
		self.query_dm_inx(dev_sn)
		#print(type(dev_sn))
		self.show_status(dev_sn)
			
	def show_online_status(self):
		dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
		self.show_status(dev_sn)
	
	def monitor_item(self,event):
		if len(self.lb_monitors.curselection()) == 0:
			return
		else:
			self.show_online_status()

	def query_device_storage(self, dev_sn):
		#adb shell df -h | grep "/dev/block/dm-" | grep "\/data" | awk '{print $5}'
		cmd = ["adb", "-s", dev_sn, "shell", "df", "-h", "|", "grep", "\/dev\/block\/dm-", "|", "grep", "\/data"]
		print("query_device_storage:"+" ".join(cmd))
		try:
			#proc = subprocess.call(cmd, shell=False)
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		
		cmd_out = bytes.decode(proc.stdout.read().split()[4])
		self.devices[dev_sn]["df"] = cmd_out
		#print(float(cmd_out.strip('%')))
		#print(self.stop_wr)
		if float(cmd_out.strip('%')) > self.stop_wr*100:
			print("stop wr thread....")
			self.devices[dev_sn]["wrfn"] = "off"
			print("start delete thread....")
			self.devices[dev_sn]["delfn"] = "on"
			self.create_del_thread(dev_sn)
			
		if float(cmd_out.strip('%')) < self.stop_del*100:
			print("stop delete thread...")
			self.devices[dev_sn]["delfn"] = "off"
			print("start wr thread...")
			if self.devices[dev_sn]["wrfn"] == "off":
				self.devices[dev_sn]["wrfn"] = "on"
				self.create_wr_thread(dev_sn)
			
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

	def calc_fragment_ratio(self, dev_sn, draw_fragment=False):
		segment= {"0":0, "512":0, "z":[]}

		path = "/proc/fs/f2fs/dm-"+self.dminx+"/segment_info"
		cmd = ["adb", "-s", dev_sn, "shell", "cat", path]
		print("calc_fragment_ratio:"+" ".join(cmd))
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None

		#i=0
		while True:
			#line = proc.stderr.readline().strip()
			#if len(line) is not 0:
			#	print(line)
			#	return None

			#if(i==10):
			#	break
			#i = i + 1
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
				segment["0"] += info["0"]
				segment["512"] += info["512"]
				segment["z"] += info["z"]
				#segment += info
		#print(segment)
		ratio = (len(segment["z"])-segment["0"]-segment["512"])/len(segment["z"])
		if draw_fragment == True:
			self.draw_fragment_info(segment["z"], ratio, dev_sn)
		#print(ratio)
		return ratio
		
	def query_device_fragment(self, dev_sn):
		ratio = self.calc_fragment_ratio(dev_sn)
		self.devices[dev_sn]["frag"] = float('%.2f' % ratio)
		return
	
	def query_device_status(self, dev_sn):
		self.query_device_storage(dev_sn)
		self.query_device_fragment(dev_sn)
		return

	#devices{"sn1":{"s":"online","fg":0.6,"frag":0.63,"stime":xxxxx,"func":"off"}}
	def wr_func(self,dev_sn,path):
		cmd_str="if [ ! -f "+path+" ];then mkdir -p "+path+";fi;"+"_tmp_size=$(($RANDOM%99+1));dd if=/dev/urandom of="+path+"/$(($RANDOM*1000+$RANDOM))_${_tmp_size}k.dat bs=${_tmp_size}k count=1;sync;"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]

		while self.devices[dev_sn]["s"] == "online" and self.devices[dev_sn]["wrfn"] == "on":
			#print(cmd_str)
			#print(cmd)

			try:
				proc = subprocess.run(cmd, shell=False)
			except OSError as e:
				print(e)
		
		return

	def del_func(self,dev_sn,path):
		#cmd_str="while [ 1 ];do file_list=`ls "+path+"/*k.dat`;j=0;for file in $file_list;do rm -f $file;j=`expr $j + 1`;echo '$j: delete "+path+"/$file';if [ $j -gt 10 ];then break;fi;done;sync;exit;done"
		cmd_str="rm -rf "+self.path+self.dir+"$(($RANDOM%99+1))/*_$(($RANDOM%99+1))k.dat;sync"
		cmd = ["adb", "-s", dev_sn, "shell", cmd_str]

		while self.devices[dev_sn]["s"] == "online" and self.devices[dev_sn]["delfn"] == "on":
			#print(cmd_str)
			#print(cmd)

			try:
				proc = subprocess.call(cmd, shell=False)
			except OSError as e:
				print(e)
		
		return

	def flush_device_info(self, dev_sn):
		return
		
	def stop_all(self):
		self.monthread = "off"
		if len(self.devices) != 0:
		#print("monitor start")
			for k in self.devices.keys():
				print(k)
				self.devices[k]["s"] = "offline"
		return
		
	def monitor_devices(self):
		while True:
			if self.monthread == "on":
				time.sleep(self.sleeptime)
				if len(self.devices) != 0:
					#print("monitor start")
					for k in self.devices.keys():
						#print(k)
						#self.query_device_status(k)
						self.show_status(k)
						#self.flush_device_info(k)
			else:
				return

	def	create_monitor_thread(self):
		print("create_monitor_thread...")
		t=threading.Thread(target=self.monitor_devices,name="fragment-test-monitor")
		t.start()
		return
		
	def create_wr_thread(self,dev):
		print("create_wr_thread...")
		for i in range(self.wrthreads):
			#print(i)
			t=threading.Thread(target=self.wr_func,name=dev+"-wr-"+str(i),args=(dev,self.path+self.dir+str(i)))
			t.start()
		return

	def create_del_thread(self,dev):
		print("create_del_thread...")
		for i in range(self.delthreads):
			#print(i)
			t=threading.Thread(target=self.del_func,name=dev+"-del-"+str(i),args=(dev,self.path+self.dir+str(i)))
			t.start()
		return
		
	def get_device_info(self):
		cmd = ["adb", "devices"]
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
					tmp_dev.append(bytes.decode(line.split()[0]))
			else:
				return tmp_dev

	def draw_fragment_info(self, segment, ratio, dev_sn):
		aa = []
		cnt = 0
		for line in segment:
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
			title="["+dev_sn+"] frag info: ["+self.devices[dev_sn]["df"]+"] "+str(float('%.2f' % ratio)),
			#height = (len(segment["z"])//10)*8,
			xaxis = dict(title = "segment row"),
			yaxis = dict(title = "segment col"),
		)

		fig = go.Figure(data=data, layout=layout)
		output_filename="f2fs_fragment_v2_"+dev_sn+".html"
		py.plot(fig,filename=output_filename)

if __name__ == '__main__':
	obj = FragmentUI("fg tool")
	obj.init_ui(obj.get_device_info())
