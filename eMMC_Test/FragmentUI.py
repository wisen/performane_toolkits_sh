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
import DeviceConfig as de
import GlobalConfig as glo
import OfflineParser as op

from tkinter import messagebox as mBox
import Version as v

import Debug as d

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
		d.init()

	def show_status_indevicelist(self, event):
		if len(self.lb_devices.curselection()) != 0:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].query_storage()
			self.devices[dev_sn].query_fragment()
			self.devices[dev_sn].load_config()
			self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			status_str="device["+dev_sn+"]: \n"
			status_str = status_str + "df: " + str(self.devices[dev_sn].storage)+"\n"
			status_str = status_str + "fs: " + str(self.devices[dev_sn].fs) + "\n"
			status_str = status_str + "frag: " + str(self.devices[dev_sn].frag)+"\n\n"
			status_str = status_str + "wrthreads: " + str(self.devices[dev_sn].wrthreads) + "\n"
			status_str = status_str + "wrdelay: " + str(self.devices[dev_sn].wrdelay) + "\n"
			status_str = status_str + "delthreads: " + str(self.devices[dev_sn].delthreads) + "\n"
			status_str = status_str + "deldelay: " + str(self.devices[dev_sn].deldelay) + "\n"
			status_str = status_str + "mondelay: " + str(self.devices[dev_sn].mondelay) + "\n"
			status_str = status_str + "detdelay: " + str(self.devices[dev_sn].detdelay) + "\n"
			status_str = status_str + "path: " + str(self.devices[dev_sn].path) + "\n"
			status_str = status_str + "dir: " + str(self.devices[dev_sn].dir) + "\n"
			status_str = status_str + "stop_wr: " + str(self.devices[dev_sn].stop_wr) + "\n"
			status_str = status_str + "stop_del: " + str(self.devices[dev_sn].stop_del) + "\n"
			status_str = status_str + "sleeptime: " + str(self.devices[dev_sn].sleeptime) + "\n"
			status_str = status_str + "dminx: " + str(self.devices[dev_sn].dminx) + "\n"
			self.scr.insert(END,status_str)
		else:
			return

	def show_status_inmonitorlist(self, event):
		if len(self.lb_monitors.curselection()) != 0:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].query_storage()
			self.devices[dev_sn].query_fragment()
			self.devices[dev_sn].load_config()
			self.scr.delete(0.0,len(self.scr.get(0.0,END))-1.0)
			status_str="device["+dev_sn+"]: \n"
			status_str=status_str+"df: "+str(self.devices[dev_sn].storage)+"\n"
			status_str = status_str + "fs: " + str(self.devices[dev_sn].fs) + "\n"
			status_str=status_str+"frag: "+str(self.devices[dev_sn].frag)+"\n\n"
			status_str = status_str + "wrthreads: " + str(self.devices[dev_sn].wrthreads) + "\n"
			status_str = status_str + "wrdelay: " + str(self.devices[dev_sn].wrdelay) + "\n"
			status_str = status_str + "delthreads: " + str(self.devices[dev_sn].delthreads) + "\n"
			status_str = status_str + "deldelay: " + str(self.devices[dev_sn].deldelay) + "\n"
			status_str = status_str + "mondelay: " + str(self.devices[dev_sn].mondelay) + "\n"
			status_str = status_str + "detdelay: " + str(self.devices[dev_sn].detdelay) + "\n"
			status_str = status_str + "path: " + str(self.devices[dev_sn].path) + "\n"
			status_str = status_str + "dir: " + str(self.devices[dev_sn].dir) + "\n"
			status_str = status_str + "stop_wr: " + str(self.devices[dev_sn].stop_wr) + "\n"
			status_str = status_str + "stop_del: " + str(self.devices[dev_sn].stop_del) + "\n"
			status_str = status_str + "sleeptime: " + str(self.devices[dev_sn].sleeptime) + "\n"
			status_str = status_str + "dminx: " + str(self.devices[dev_sn].dminx) + "\n"
			self.scr.insert(END,status_str)
		else:
			return

	def _quit(self):
		self.window_close()
		
	def window_close(self):
		self.stop_monitorthread()
		self.stop_all_devices()
		self.root.destroy()

	def about(self):
		about.About("about").initUI()

	def help(self):
		return

	def config_global(self):
		glo.GlobalConfig("Global Config").initUI()

	def config_device(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			de.DeviceConfig("Config Device " + dev_sn, self.devices[dev_sn]).initUI()
		return

	def offline_parser(self):
		op.OfflineParser("Offline Parser Tool "+v.version).initUI()
		return

	def initUI(self):
		root = Tk()
		root.title(self.name)
		root.geometry("720x400+300+200")
		root.resizable(width=False, height=False)
		#root.iconbitmap(r"/home/wisen/performane_toolkits_sh/eMMC_Test/emmc.ico")
		self.root = root

		s = ttk.Style()
		s.theme_use('classic')

		### menu start ###
		menuBar = Menu(root, font=("Monospace Regular",16))
		root.config(menu=menuBar)
		fileMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Tools", menu=fileMenu)
		fileMenu.add_command(label="Offline Parser", font=("Monospace Regular", 16), command=self.offline_parser)
		#fileMenu.add_command(label="Exit")
		fileMenu.add_separator()
		fileMenu.add_command(label="Exit", command=self._quit, font=("Monospace Regular",16))
		
		configMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Config", menu=configMenu)
		configMenu.add_command(label="Global", font=("Monospace Regular",16), command=self.config_global)
		configMenu.add_command(label="Device", font=("Monospace Regular",16), command=self.config_device)
		
		helpMenu = Menu(menuBar, tearoff=0)
		menuBar.add_cascade(label="Help", menu=helpMenu)
		helpMenu.add_command(label="About", font=("Monospace Regular",16), command=self.about)
		helpMenu.add_separator()
		helpMenu.add_command(label="Help", font=("Monospace Regular",16), command=self.help)
		### menu end ###

		#######################Tab control##############################
		tabControl = ttk.Notebook(root)
		tab_fragtest = ttk.Frame(tabControl)
		tab_throughputtest = ttk.Frame(tabControl)
		tab_iopstest = ttk.Frame(tabControl)
		tab_iolantencytest = ttk.Frame(tabControl)

		tabControl.add(tab_fragtest, text="Fragment Test")
		tabControl.add(tab_throughputtest, text="Throughput Test")
		tabControl.add(tab_iopstest, text="IOPS Test")
		tabControl.add(tab_iolantencytest, text="IO Lantency Test")
		tabControl.grid(column=0,row=0)
		#frm = ttk.LabelFrame(root,text="Fragment tool V1.0").grid(column=0,row=0)

		#######################Fragment Test Start######################
		## frm_devices start
		ttk.Label(tab_fragtest, text="Pending List", font=("Monospace Regular",16)).grid(column=0,row=0,columnspan=2, sticky=W)

		var = StringVar()
		lb_devices = Listbox(tab_fragtest, font=("Monospace Regular",16), width=20, height=13, listvariable = var)
		lb_devices.grid(column=0,row=1,rowspan=2,columnspan=2)
		self.lb_devices = lb_devices

		lb_devices.bind('<ButtonRelease-1>', self.show_status_indevicelist)

		## popmenuBar_devices start
		self.create_popmenuBar_devices()
		lb_devices.bind("<ButtonRelease-3>", self.pop_on_deviceslist)
		## popmenuBar_devices end

		start_btn = ttk.Button(tab_fragtest, text=">>>", command=self.add_device)
		start_btn.grid(column=2,row=1,sticky=S)
		stop_btn = ttk.Button(tab_fragtest, text="<<<", command=self.delete_device)
		stop_btn.grid(column=2,row=2,sticky=N)

		ttk.Label(tab_fragtest, text="Monitor devices", font=("Monospace Regular",16)).grid(column=3,row=0, sticky=W)
		var = StringVar()
		lb_monitors = Listbox(tab_fragtest, font=("Monospace Regular",16), width=20, height=13, listvariable = var)
		lb_monitors.grid(column=3,row=1,rowspan=2)
		self.lb_monitors = lb_monitors
		
		## popmenuBar_monitor start
		self.create_popmenuBar_monitor()
		lb_monitors.bind("<ButtonRelease-3>", self.pop_on_monitorlist)
		## popmenuBar_monitor end
		lb_monitors.bind('<ButtonRelease-1>', self.show_status_inmonitorlist)

		## frm_status start
		ttk.Label(tab_fragtest, text="Device status", font=("Monospace Regular",16)).grid(column=4,row=0, sticky=W)
		scrolW = 29
		scrolH = 17
		scr = scrolledtext.ScrolledText(tab_fragtest, width=scrolW, height=scrolH, wrap=WORD, font=("Monospace Regular",12))
		scr.grid(column=4, row=1, rowspan=2)
		self.scr = scr	

		self.start_monitorthread()
		self.root.bind('<ButtonRelease-1>', self.destroy_popmenu)
		#######################Fragment Test Start######################

		root.protocol("WM_DELETE_WINDOW", self.window_close)
		root.mainloop()

	def destroy_popmenu(self, event):
		if self.popmenuBar_devices:
			self.popmenuBar_devices.destroy()
		if self.popmenuBar_monitor:
			self.popmenuBar_monitor.destroy()

	def create_popmenuBar_devices(self):
		popmenuBar_devices = Menu(self.root, font=("Monospace Regular",16), tearoff=0)
		popmenuBar_devices.add_command(label="Add Device", command=self.add_device)
		popmenuBar_devices.add_command(label="Add All", command=self.add_all_devices)
		popmenuBar_devices.add_separator()		
		popmenuBar_devices.add_command(label="Draw Fragment(plotly)", command=self.draw_fragment_byplotly_on_devicelist)
		popmenuBar_devices.add_command(label="Draw Fragment(matplot)", command=self.draw_fragment_bymatplot_on_devicelist)
		popmenuBar_devices.add_command(label="Draw Animation", command=self.draw_animation_on_devicelist)
		popmenuBar_devices.add_command(label="Save Animation(mp4)", command=self.save_animation_tomp4_on_devicelist)
		popmenuBar_devices.add_command(label="Save Animation(gif)", command=self.save_animation_togif_on_devicelist)
		popmenuBar_devices.add_command(label="Draw Plot(frag)", command=self.draw_fragment_plot_on_devicelist)
		popmenuBar_devices.add_command(label="Draw Plot(both)", command=self.draw_both_plot_on_devicelist)
		popmenuBar_devices.add_separator()
		popmenuBar_devices.add_command(label="Config Device", command=self.config_device)
		self.popmenuBar_devices = popmenuBar_devices		

	def pop_on_deviceslist(self,event):
		self.create_popmenuBar_devices()
		self.popmenuBar_devices.post(event.x_root,event.y_root)

	def create_popmenuBar_monitor(self):
		popmenuBar_monitor = Menu(self.root, font=("Monospace Regular",16), tearoff=0)
		popmenuBar_monitor.add_command(label="Delete Device", command=self.delete_device)
		popmenuBar_monitor.add_command(label="Delete All", command=self.delete_all_devices)
		popmenuBar_monitor.add_separator()
		popmenuBar_monitor.add_command(label="Draw Fragment(plotly)", command=self.draw_fragment_byplotly_on_monitorlist)
		popmenuBar_monitor.add_command(label="Draw Fragment(matplot)", command=self.draw_fragment_bymatplot_on_monitorlist)
		popmenuBar_monitor.add_command(label="Draw Animation", command=self.draw_animation_on_monitorlist)
		popmenuBar_monitor.add_command(label="Save Animation(mp4)", command=self.save_animation_tomp4_on_monitorlist)
		popmenuBar_monitor.add_command(label="Save Animation(gif)", command=self.save_animation_togif_on_monitorlist)
		popmenuBar_monitor.add_command(label="Draw Plot(frag)", command=self.draw_fragment_plot_on_monitorlist)
		popmenuBar_monitor.add_command(label="Draw Plot(both)", command=self.draw_both_plot_on_monitorlist)
		self.popmenuBar_monitor = popmenuBar_monitor		
		
	def pop_on_monitorlist(self,event):
		self.create_popmenuBar_monitor()
		self.popmenuBar_monitor.post(event.x_root,event.y_root)

	def No_Select(self):
		mBox.showinfo('Alert', "Please select a device!!!")
		return

	def draw_fragment_byplotly_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_byplotly()
		return

	def draw_fragment_byplotly_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_byplotly()
		return

	def draw_fragment_bymatplot_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_bymatplot()
		return

	def draw_fragment_bymatplot_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_bymatplot()
		return

	def draw_animation_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation()
		return

	def save_animation_tomp4_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation(True, "mp4")
		return

	def save_animation_togif_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation(True, "gif")
		return

	def draw_animation_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation()
		return

	def save_animation_tomp4_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation(True, "mp4")
		return

	def save_animation_togif_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_heatmap_animation(True, "gif")
		return

	def draw_both_plot_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_both_bytime()
		return

	def draw_both_plot_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn = self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_both_bytime()
		return

	def draw_fragment_plot_on_devicelist(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.devices[dev_sn].draw_fragment_ratio_bytime()
		return

	def draw_fragment_plot_on_monitorlist(self):
		if len(self.lb_monitors.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_monitors.get(self.lb_monitors.curselection())
			self.devices[dev_sn].draw_fragment_ratio_bytime()
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
			d.d(self.devices)
		#print(threading.enumerate())
		else:
			self.No_Select()
		return
		
	def delete_all_devices(self):
		if self.lb_monitors.size() == 0:
			mBox.showinfo('Alert', "There are no devices be monitored!")
			return
		else:
			for i in range(self.lb_monitors.size()):
				dev_sn = self.lb_monitors.get(i)
				self.lb_monitors.delete(i)
				self.lb_devices.insert(END, dev_sn)

				if self.devices[dev_sn].has_moning:
					self.devices[dev_sn].stop_monthread()
		return
		
	def add_device(self):
		if len(self.lb_devices.curselection()) == 0:
			self.No_Select()
			return
		else:
			dev_sn=self.lb_devices.get(self.lb_devices.curselection())
			self.lb_devices.delete(self.lb_devices.curselection())
			self.lb_monitors.insert(END, dev_sn)
			if not self.devices[dev_sn].has_wring:
				self.devices[dev_sn].start_wrthreads()
			if not self.devices[dev_sn].has_moning:
				self.devices[dev_sn].start_monthread()
		return
		
	def add_all_devices(self):
		if self.lb_devices.size() == 0:
			mBox.showinfo('Alert', "There are no devices connected!")
			return
		else:
			cnt = self.lb_devices.size()
			for i in range(cnt):
				dev_sn = self.lb_devices.get(0)
				self.lb_devices.delete(0)
				self.lb_monitors.insert(END, dev_sn)
				if not self.devices[dev_sn].has_wring:
					self.devices[dev_sn].start_wrthreads()
				if not self.devices[dev_sn].has_moning:
					self.devices[dev_sn].start_monthread()
		return
		
	def stop_monitorthread(self):
		d.d("stop_monitorthread.....")
		self.monitor_stopevt.set()
		return
	
	def start_monitorthread(self):
		d.d("start_monitorthread.....")
		self.monitor_stopevt = threading.Event()
		t=RLKThread.RLKThread(stopevt=self.monitor_stopevt, name="FUI-mon-devices-0", target=self.monitor_devices, args="", kwargs={}, delay=1)
		t.start()
	
	def monitor_devices(self, args, kwargs):
		#print("monitor_devices.....")
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

		for dev_sn in list(self.devices):
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
		#print(self.devices)
	
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
	obj = FragmentUI(v.name+" "+v.version)
	obj.initUI()
