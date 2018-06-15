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

class About():

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
		root.title("About This Tool")
		root.geometry("300x200+300+200")
		root.resizable(width=False, height=False)
		self.root = root
		
		ttk.Label(root, text="eMMC Test Tool\n\nVersion: 2.0\nAuthor: Wisen Wang", font=("Monospace Regular",16)).grid(column=0,row=0, sticky=W)

		root.mainloop()
		
if __name__ == '__main__':
	obj = About("About Dialog")
	obj.initUI()