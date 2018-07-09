from tkinter import *
from tkinter import ttk
import tkinter as tk

import tkinter.messagebox as msg
import configparser as cp

import os
import Util as u

class GlobalConfig():

	def __init__(self, name):
		self.name = name
		self.ini_file = "conf/global.ini"
		self.config_dir = "./conf"
		self.ini_elements = {}

	def parse_ini_file(self, ini_file):
		self.active_ini = cp.ConfigParser()
		self.active_ini.read(ini_file)
		self.active_ini_filename = ini_file
		self.display_section_contents()

	def save_config(self, event=None):
		for key in self.active_ini["SETTING"]:
			self.active_ini["SETTING"][key] = self.ini_elements[key].get()
		with open(self.active_ini_filename, "w") as ini_file:
			self.active_ini.write(ini_file)
		msg.showinfo("Saved", "File Saved Successfully")

	def apply_config(self):
		for files in os.walk(self.config_dir):
			for file in files[2]:
				if os.path.splitext(file)[1] == '.ini' and os.path.splitext(file)[0] != 'global':
					u.copyfile(self.ini_file, 'conf/'+os.path.splitext(file)[0]+'.ini')
		return

	def display_section_contents(self, event=None):
		i = 0
		for key in self.active_ini["SETTING"]:
			new_label = ttk.Label(self.root, text=key, font=(None, 12)).grid(column=0, row=i, sticky=W)
			#print(key+" "+self.active_ini["SETTING"][key])
			value = self.active_ini["SETTING"][key]
			ini_element = ttk.Entry(self.root)
			ini_element.grid(column=1, row=i)
			ini_element.insert(0, value)
			self.ini_elements[key] = ini_element
			i = i+1

		save_button = tk.Button(self.root, text="Save Config", command=self.save_config)
		save_button.grid(column=0, row=i, sticky=W)
		apply_button = tk.Button(self.root, text="Apply Config", command=self.apply_config)
		apply_button.grid(column=1, row=i, sticky=E)

		return

	def initUI(self):
		root = Tk()
		root.title(self.name)
		root.geometry("300x400+300+200")
		root.resizable(width=False, height=False)
		self.root = root
		self.parse_ini_file(self.ini_file)

		root.mainloop()


if __name__ == '__main__':
	obj = GlobalConfig("Global Config")
	obj.initUI()