#!/usr/bin/env python 

import About as about

from tkinter import *
from tkinter import ttk
from tkinter import scrolledtext
import threading
import RLKThread
import subprocess
import RLKDB
import RLKDevice

from tkinter import messagebox as mBox
import numpy as np
import pandas as pd
import plotly.offline as py
import plotly.graph_objs as go

class FragmentUI:

	def __init__(self,name):
		self.name = name
		self.devices = {}
		self.gl_wrthreads = 10
		self.gl_delthreads = 5
		self.gl_path = "/sdcard/tmp/"
		self.gl_dir = "dir"
		self.gl_stop_wr = 0.95
		self.gl_stop_del = 0.90
		self.gl_sleeptime = 10
		self.gl_monthread = "on"
		self.gl_dminx = "0"

	def show_status_indevicelist(self, event):
		if len(self.lb_devices.curselection()) != 0:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].query_storage()
			self.devices[dev_sn].query_fragment()
			self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			status_str="device["+dev_sn+"]: \n"
			status_str=status_str+"df: "+str(self.devices[dev_sn].storage)+"\n"
			status_str=status_str+"frag: "+str(self.devices[dev_sn].frag)+"\n"
			self.scr.insert(END,status_str)
		else:
			return
		
	def show_status_inmonitorlist(self, event):
		if len(self.lb_monitors.curselection()) != 0:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].query_storage()
			self.devices[dev_sn].query_fragment()
			self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			status_str="device["+dev_sn+"]: \n"
			status_str=status_str+"df: "+str(self.devices[dev_sn].storage)+"\n"
			status_str=status_str+"frag: "+str(self.devices[dev_sn].frag)+"\n"
			self.scr.insert(END,status_str)
		else:
			return
	def _quit(self):
		self.window_close()
		
	def window_close(self):
		self.stop_monitorthread()
		self.stop_all_devices()
		self.root.destroy()
		print("window_close")

	def about(self):
		self.about = about.About("about")
		self.about.initUI()

	def initUI(self):
		root = Tk()
		root.title("Fragment tools V2.0")
		root.geometry("720x400+300+200")
		root.resizable(width=False, height=False)
		self.root = root
		
		s = ttk.Style()
		s.theme_use('classic')

		### menu start ###
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
		configMenu.add_command(label="Device", font=("Monospace Regular",16))
		
		helpMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Help", menu=helpMenu)
		helpMenu.add_command(label="About", font=("Monospace Regular",16), command=self.about)
		helpMenu.add_separator()
		helpMenu.add_command(label="Help", font=("Monospace Regular",16))
		### menu end ###
		
		frm = ttk.LabelFrame(root,text="Fragment tool V1.0").grid(column=0,row=0)

		## frm_devices start
		ttk.Label(text="Pending List", font=("Monospace Regular",16)).grid(column=0,row=0,columnspan=2, sticky=W)

		var = StringVar()
		lb_devices = Listbox(frm, font=("Monospace Regular",16), width=20, listvariable = var)
		lb_devices.grid(column=0,row=1,rowspan=2,columnspan=2)
		self.lb_devices = lb_devices
		print(lb_devices)

		lb_devices.bind('<ButtonRelease-1>', self.show_status_indevicelist)
		#list_item = listitems
		#for item in list_item:
		#	lb_devices.insert(END, item)

		## popmenuBar_devices start
		self.create_popmenuBar_devices()
		lb_devices.bind("<ButtonRelease-3>", self.pop_on_deviceslist)
		## popmenuBar_devices end

		start_btn = ttk.Button(frm, text=">>>", command=self.add_device)
		start_btn.grid(column=2,row=1,sticky=S)
		stop_btn = ttk.Button(frm, text="<<<", command=self.delete_device)
		stop_btn.grid(column=2,row=2,sticky=N)
			
		ttk.Label(text="Monitor devices", font=("Monospace Regular",16)).grid(column=3,row=0, sticky=W)
		var = StringVar()
		lb_monitors = Listbox(frm, font=("Monospace Regular",16), width=20, listvariable = var)
		lb_monitors.grid(column=3,row=1,rowspan=2)
		self.lb_monitors = lb_monitors
		
		## popmenuBar_monitor start
		self.create_popmenuBar_monitor()
		lb_monitors.bind("<ButtonRelease-3>", self.pop_on_monitorlist)
		## popmenuBar_monitor end
		lb_monitors.bind('<ButtonRelease-1>', self.show_status_inmonitorlist)

		## frm_status start
		ttk.Label(text="Device status", font=("Monospace Regular",16)).grid(column=4,row=0, sticky=W)
		scrolW = 29 # 设置文本框的长度
		scrolH = 13 # 设置文本框的高度
		scr = scrolledtext.ScrolledText(frm, width=scrolW, height=scrolH, wrap=WORD, font=("Monospace Regular",12)) 
		scr.grid(column=4, row=1, rowspan=2)
		self.scr = scr	
		
		self.start_monitorthread()
		
		## UI loop start
		self.root.bind('<ButtonRelease-1>', self.destroy_popmenu)
		root.protocol("WM_DELETE_WINDOW", self.window_close)
		root.mainloop()

	def destroy_popmenu(self, event):
		if self.popmenuBar_devices:
			self.popmenuBar_devices.destroy()
		if self.popmenuBar_monitor:
			self.popmenuBar_monitor.destroy()

	def create_popmenuBar_devices(self):
		popmenuBar_devices = Menu(self.root, font=("Monospace Regular",16), tearoff=0)
		popmenuBar_devices.add_command(label="add device", command=self.add_device)
		popmenuBar_devices.add_command(label="add all", command=self.add_all_devices)
		popmenuBar_devices.add_separator()		
		popmenuBar_devices.add_command(label="draw fragment", command=self.draw_fragment_on_devicelist)
		popmenuBar_devices.add_command(label="draw animation", command=self.draw_animation)
		self.popmenuBar_devices = popmenuBar_devices		

	def pop_on_deviceslist(self,event):
		self.create_popmenuBar_devices()
		self.popmenuBar_devices.post(event.x_root,event.y_root)

	def create_popmenuBar_monitor(self):
		popmenuBar_monitor = Menu(self.root, font=("Monospace Regular",16), tearoff=0)
		popmenuBar_monitor.add_command(label="delete device", command=self.delete_device)
		popmenuBar_monitor.add_command(label="delete all", command=self.delete_all_devices)
		popmenuBar_monitor.add_separator()
		popmenuBar_monitor.add_command(label="draw fragment", command=self.draw_fragment_on_monitorlist)
		popmenuBar_monitor.add_command(label="draw animation", command=self.draw_animation)
		self.popmenuBar_monitor = popmenuBar_monitor		
		
	def pop_on_monitorlist(self,event):
		self.create_popmenuBar_monitor()
		self.popmenuBar_monitor.post(event.x_root,event.y_root)

	def No_Select(self):
		mBox.showinfo('Alert', "Please select a device!!!")
		return
		
	def draw_fragment_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap()
		return

	def draw_fragment_on_monitorlist(self):	
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap()
		return
		
	def draw_animation(self):
		return
	
	def stop_all_devices(self):
		for dev_sn in self.devices.keys():
			self.devices[dev_sn].stop_detectthread()
			if self.devices[dev_sn].has_moning:
				self.devices[dev_sn].stop_monthread()
		return
	
	def delete_device(self):
		if len(self.lb_monitors.curselection()) != 0:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.lb_monitors.delete(self.lb_monitors.curselection())
			self.lb_devices.insert(END, dev_sn)

			if self.devices[dev_sn].has_moning:
				self.devices[dev_sn].stop_monthread()
			#self.devices[dev_sn].stop_detectthread()
			#self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			print(self.devices)
		#print(threading.enumerate())
		else:
			self.No_Select()
		return
		
	def delete_all_devices(self):
		return
		
	def add_device(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.lb_devices.delete(self.lb_devices.curselection())
			self.lb_monitors.insert(END, dev_sn)
			if not self.devices[dev_sn].has_moning:
				self.devices[dev_sn].start_monthread()
		return
		
	def add_all_devices(self):
		return
		
	def stop_monitorthread(self):
		print("stop_monitorthread.....")
		self.monitor_stopevt.set()
		return
	
	def start_monitorthread(self):
		print("start_monitorthread.....")
		self.monitor_stopevt = threading.Event()
		t=RLKThread.RLKThread(stopevt=self.monitor_stopevt, name="FUI-mon-devices-0", target=self.monitor_devices, args="", kwargs={}, delay=3)
		t.start()
	
	def monitor_devices(self, args, kwargs):
		print("monitor_devices.....")
		cmd = ["adb", "devices"]
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		i = 0
		while True:
			line = proc.stdout.readline().strip()
			if len(line) is not 0:
				if line[0:4] == b'List' or line[0:1] == b'*':
					continue
				else:
					tmp_devsn = bytes.decode(line.split()[0])
					if tmp_devsn in self.devices.keys():
						continue
					else:
						db = RLKDB.RLKDB("dbs/"+tmp_devsn+".db")
						device = RLKDevice.RLKDevice(tmp_devsn, db)
						device.start_detectthread()
						self.devices[tmp_devsn]=device	
						self.lb_devices.insert(END, tmp_devsn)
			else:
				break

		#for dev_sn in self.devices.keys():
		for dev_sn in list(self.devices):
			#print(dev_sn+":"+self.devices[dev_sn].status+" inx: "+ str(self.lb_devices.get(0, "end").index(dev_sn)))
			if self.devices[dev_sn].status == "offline":
				if dev_sn in self.lb_monitors.get(0, "end"):
					self.lb_monitors.delete(self.lb_monitors.get(0, "end").index(dev_sn))
					if self.devices[dev_sn].has_moning:
						self.devices[dev_sn].stop_monthread()
					self.devices[dev_sn].stop_detectthread()
					self.devices.pop(dev_sn)
				if dev_sn in self.lb_devices.get(0, "end"):
					self.lb_devices.delete(self.lb_devices.get(0, "end").index(dev_sn))
					self.devices[dev_sn].stop_detectthread()
					self.devices.pop(dev_sn)
		print(self.devices)
	
	def init_devices(self):
		cmd = ["adb", "devices"]
		try:
			proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		except OSError as e:
			print(e)
			return None
		i = 0
		while True:
			line = proc.stdout.readline().strip()
			if len(line) is not 0:
				if line[0:4] == b'List' or line[0:1] == b'*':
					continue
				else:
					tmp_devsn = bytes.decode(line.split()[0])
					db = RLKDB.RLKDB("dbs/"+tmp_devsn+".db")
					device = RLKDevice.RLKDevice(tmp_devsn, db)
					self.devices.append({tmp_devsn:device})
		
if __name__ == '__main__':
	obj = FragmentUI("Fragment tool V2.0")
	obj.initUI()