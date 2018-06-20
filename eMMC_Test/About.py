from tkinter import *
from tkinter import ttk
import Version as v

class About():

	def __init__(self, name):
		self.name = name
		self.delthreads = 5
		self.wrthreads = 10
		self.sleeptime = 10
		self.stop_wr = False
		self.stop_del = True
		
	def initUI(self):
		root = Tk()
		root.title(self.name)
		root.geometry("400x300+300+200")
		root.resizable(width=False, height=False)
		self.root = root

		str = v.name + "\n\n"
		str = str + "Version: " + v.version + "\n\n"
		str = str + "Author: " + v.author + "\n\n"
		str = str + "Email: " + v.email + "\n\n"
		str = str + "Github: " + v.github + "\n\n"
		ttk.Label(root, text=str, font=("Monospace Regular",16)).grid(column=0,row=0, sticky=W)

		root.mainloop()
		
if __name__ == '__main__':
	obj = About("About " + v.name)
	obj.initUI()