#!/usr/bin/env python

from tkinter import *
from tkinter import ttk
import RLKDB
import RLKDevice

from tkinter import messagebox as mBox
from tkinter import filedialog as fd
import os
from os import path
import Version as v

class OfflineParser:

    def __init__(self, name):
        self.name = name
        self.devices = {}
        return

    def opendb_dialog(self):
        fDir = path.dirname(__file__)
        dbfilename = fd.askopenfilename(parent=self.root, initialdir=fDir)
        (filepath, tempfilename) = os.path.split(dbfilename)
        (dev_sn, extension) = os.path.splitext(tempfilename)
        self.add_dbdevice_to_parserlist(dbfilename, dev_sn)
        return

    def initUI(self):
        root = Tk()
        root.title(self.name)
        root.geometry("295x400+300+200")
        root.resizable(width=False, height=False)
        self.root = root

        ### menu start ###
        menuBar = Menu(root, font=("Monospace Regular", 16))
        root.config(menu=menuBar)
        fileMenu = Menu(menuBar, tearoff=0)
        menuBar.add_cascade(label="Tools", menu=fileMenu)
        fileMenu.add_command(label="Open DB", font=("Monospace Regular", 16), command=self.opendb_dialog)

        ttk.Label(root, text="Parse List", font=("Monospace Regular", 16)).grid(column=0, row=0)
        var = StringVar()
        lb_devices = Listbox(root, font=("Monospace Regular", 16), width=29, height=13, listvariable=var)
        lb_devices.grid(column=0, row=1)
        self.lb_devices = lb_devices

        ## popmenuBar_devices start
        self.create_popmenuBar_devices()
        lb_devices.bind("<ButtonRelease-3>", self.pop_on_deviceslist)

        root.protocol("WM_DELETE_WINDOW", self.window_close)
        root.mainloop()

    def window_close(self):
        self.root.destroy()

    def add_dbdevice_to_parserlist(self, dbfile, dev_sn):
        db = RLKDB.RLKDB(dbfile)
        device = RLKDevice.RLKDevice(dev_sn, db, True)
        self.devices[dev_sn] = device
        self.lb_devices.insert(END, dev_sn)
        return

    def create_popmenuBar_devices(self):
        popmenuBar_devices = Menu(self.root, font=("Monospace Regular", 16), tearoff=0)
        popmenuBar_devices.add_command(label="Draw Fragment(plotly)", command=self.draw_fragment_byplotly_on_devicelist)
        popmenuBar_devices.add_command(label="Draw Fragment(matplot)",
                                       command=self.draw_fragment_bymatplot_on_devicelist)
        popmenuBar_devices.add_command(label="Draw Animation", command=self.draw_animation_on_devicelist)
        popmenuBar_devices.add_command(label="Draw Plot(frag)", command=self.draw_fragment_plot_on_devicelist)
        popmenuBar_devices.add_command(label="Draw Plot(both)", command=self.draw_both_plot_on_devicelist)
        self.popmenuBar_devices = popmenuBar_devices

    def pop_on_deviceslist(self, event):
        self.create_popmenuBar_devices()
        self.popmenuBar_devices.post(event.x_root, event.y_root)


    def No_Select(self):
        mBox.showinfo('Alert', "Please select a device!!!")
        return

    def draw_fragment_byplotly_on_devicelist(self):
        if len(self.lb_devices.curselection()) == 0:
            self.No_Select()
            return
        else:
            dev_sn = self.lb_devices.get(self.lb_devices.curselection())
            self.devices[dev_sn].draw_fragment_heatmap_byplotly()
        return

    def draw_fragment_bymatplot_on_devicelist(self):
        if len(self.lb_devices.curselection()) == 0:
            self.No_Select()
            return
        else:
            dev_sn = self.lb_devices.get(self.lb_devices.curselection())
            self.devices[dev_sn].draw_fragment_heatmap_bymatplot()
        return

    def draw_animation_on_devicelist(self):
        if len(self.lb_devices.curselection()) == 0:
            self.No_Select()
            return
        else:
            dev_sn = self.lb_devices.get(self.lb_devices.curselection())
            self.devices[dev_sn].draw_fragment_heatmap_animation()
        return

    def draw_both_plot_on_devicelist(self):
        if len(self.lb_devices.curselection()) == 0:
            self.No_Select()
            return
        else:
            dev_sn = self.lb_devices.get(self.lb_devices.curselection())
            self.devices[dev_sn].draw_both_bytime()
        return

    def draw_fragment_plot_on_devicelist(self):
        if len(self.lb_devices.curselection()) == 0:
            self.No_Select()
            return
        else:
            dev_sn = self.lb_devices.get(self.lb_devices.curselection())
            self.devices[dev_sn].draw_fragment_ratio_bytime()
        return


if __name__ == "__main__":
    op = OfflineParser(v.name)
    op.initUI()