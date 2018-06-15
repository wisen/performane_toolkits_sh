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

	def update_config(self):
		print("update_config...")

	def initUI(self):
		root = Tk()
		root.title("Device Config")
		root.geometry("300x200+300+200")
		root.resizable(width=False, height=False)
		self.root = root

		# s = ttk.Style()
		# s.theme_use('classic')

		# frm = ttk.LabelFrame(root,text="Global Fragment").grid(column=0,row=0)

		ttk.Label(root, text="WR threads:", font=("Monospace Regular", 16)).grid(column=0, row=0, sticky=W)
		self.wrname = StringVar()
		wrnameEntered = ttk.Entry(root, width=10, textvariable=self.wrname)
		wrnameEntered.grid(column=1, row=0)
		wrnameEntered.insert(10, self.wrthreads)
		wrnameEntered.focus()

		ttk.Label(root, text="DEL threads:", font=("Monospace Regular", 16)).grid(column=0, row=1, sticky=W)
		self.delname = StringVar()
		delnameEntered = ttk.Entry(root, width=10, textvariable=self.delname)
		delnameEntered.insert(10, self.delthreads)
		delnameEntered.grid(column=1, row=1)

		ttk.Label(root, text="Sleep time:", font=("Monospace Regular", 16)).grid(column=0, row=2, sticky=W)
		self.sleepname = StringVar()
		sleepnameEntered = ttk.Entry(root, width=10, textvariable=self.sleepname)
		sleepnameEntered.insert(10, self.sleeptime)
		sleepnameEntered.grid(column=1, row=2)

		ttk.Label(root, text="Max percent:", font=("Monospace Regular", 16)).grid(column=0, row=3, sticky=W)
		self.maxname = StringVar()
		maxnameEntered = ttk.Entry(root, width=10, textvariable=self.maxname)
		maxnameEntered.insert(10, self.stop_wr)
		maxnameEntered.grid(column=1, row=3)

		ttk.Label(root, text="Min percent:", font=("Monospace Regular", 16)).grid(column=0, row=4, sticky=W)
		self.minname = StringVar()
		minnameEntered = ttk.Entry(root, width=10, textvariable=self.minname)
		minnameEntered.insert(10, self.stop_del)
		minnameEntered.grid(column=1, row=4)

		update_config_btn = ttk.Button(root, text="Update", command=self.update_config)
		update_config_btn.grid(column=1, row=5)

		## UI loop start
		# self.ui = root
		# root.protocol("WM_DELETE_WINDOW", self.window_cloe)
		root.mainloop()


if __name__ == '__main__':
	obj = DeviceConfig("Device Config")
	obj.initUI()