import os
import math
import subprocess
import datetime
import time
import re
import random
import threading

from tkinter import *
from tkinter import ttk
from tkinter import scrolledtext

import numpy as np
import pandas as pd
import plotly.offline as py
import plotly.graph_objs as go

class DeviceConfig():

	def __init__(self, name):
		self.delthreads = 5
		self.wrthreads = 10
		self.sleeptime = 10
		self.stop_wr = False
		self.stop_del = True
		print("__init__...")

	def update_config(self):
		print("update_config...")
		
	def initUI(self):
		root = Tk()
		root.title("Global Config")
		root.geometry("360x300")
		root.resizable(width=False, height=False)
		self.root = root

		s = ttk.Style()
		s.theme_use('classic')
		
		frm = ttk.LabelFrame(root,text="Fragment tool V1.0").grid(column=0,row=0)
		
		ttk.Label(text="WR threads:", font=("Monospace Regular",16)).grid(column=0,row=3, sticky=W)
		self.wrname = StringVar()
		wrnameEntered = ttk.Entry(frm, width=10, textvariable=self.wrname)
		wrnameEntered.grid(column=1, row=3)
		wrnameEntered.insert(10, self.wrthreads)
		wrnameEntered.focus()   
		
		ttk.Label(text="DEL threads:", font=("Monospace Regular",16)).grid(column=0,row=4, sticky=W)
		self.delname = StringVar()
		delnameEntered = ttk.Entry(frm, width=10, textvariable=self.delname)
		delnameEntered.insert(10, self.delthreads)
		delnameEntered.grid(column=1, row=4)
	
		ttk.Label(text="Sleep time:", font=("Monospace Regular",16)).grid(column=0,row=5, sticky=W)
		self.sleepname = StringVar()
		sleepnameEntered = ttk.Entry(frm, width=10, textvariable=self.sleepname)
		sleepnameEntered.insert(10, self.sleeptime)
		sleepnameEntered.grid(column=1, row=5)
		
		ttk.Label(text="Max percent:", font=("Monospace Regular",16)).grid(column=0,row=6, sticky=W)
		self.maxname = StringVar()
		maxnameEntered = ttk.Entry(frm, width=10, textvariable=self.maxname)
		maxnameEntered.insert(10, self.stop_wr)
		maxnameEntered.grid(column=1, row=6) 
		
		ttk.Label(text="Min percent:", font=("Monospace Regular",16)).grid(column=0,row=7, sticky=W)
		self.minname = StringVar()
		minnameEntered = ttk.Entry(frm, width=10, textvariable=self.minname)
		minnameEntered.insert(10, self.stop_del)
		minnameEntered.grid(column=1, row=7) 
	
		update_config_btn = ttk.Button(frm, text="Update", command=self.update_config)
		update_config_btn.grid(column=1,row=8)
		
		## UI loop start
		#self.ui = root
		#root.protocol("WM_DELETE_WINDOW", self.window_cloe)
		root.mainloop()
		
if __name__ == '__main__':
	obj = DeviceConfig("device config tool")
	obj.initUI()