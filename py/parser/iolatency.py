#!/usr/bin/env python

import numpy as np
import sys
import matplotlib.pyplot as plt
import xlwt
from matplotlib.pyplot import savefig 

secondprj=False

appname=sys.argv[1]

proname1=sys.argv[2]
filename1=sys.argv[3]
rwstrt1=sys.argv[4]

if sys.argv[5].strip():
	secondprj=True

if secondprj:
	proname2=sys.argv[5]
	filename2=sys.argv[6]
	rwstrt2=sys.argv[7]

print(proname1+": "+rwstrt1)

if secondprj:
	print(proname2+": "+rwstrt2)

#sys.exit()

filep1=open(filename1,'rb')
numio1=0
ioarr1=[]
iola50_1=0
iola100_1=0
iola150_1=0
iosum1=0

for line in filep1.readlines():
	iola1,=line.split()
	ioarr1.append(float(iola1))
	numio1=numio1+1
	iosum1=iosum1+float(iola1)
	tmpiola=float(iola1)*1000
	if tmpiola >= 150:
		iola150_1=iola150_1+1
	elif tmpiola >= 100:
		iola100_1=iola100_1+1
	elif tmpiola >= 50:
		iola50_1=iola50_1+1

if secondprj:
	filep2=open(filename2,'rb')
	numio2=0
	ioarr2=[]
	iola50_2=0
	iola100_2=0
	iola150_2=0
	iosum2=0

	for line in filep2.readlines():
		iola2,=line.split()
		ioarr2.append(float(iola2))
		numio2=numio2+1
		iosum2=iosum2+float(iola2)
		tmpiola=float(iola2)*1000
		if tmpiola >= 150:
			iola150_2=iola150_2+1
		elif tmpiola >= 100:
			iola100_2=iola100_2+1
		elif tmpiola >= 50:
			iola50_2=iola50_2+1

if secondprj:
	print("\nIOs: "+proname1+"["+str(numio1)+"] "+proname2+"["+str(numio2) + "]")
	print("\nlatency\t"+proname1+"\t"+proname2)
	print("50ms\t"+str(iola50_1)+"\t"+str(iola50_2))
	print("100ms\t"+str(iola100_1)+"\t"+str(iola100_2))
	print("150ms\t"+str(iola150_1)+"\t"+str(iola150_2))
	print("avg\t"+str(float('%.2f' % (iosum1/numio1*1000)))+"\t"+str(float('%.2f' % (iosum2/numio2*1000))))
else:
	print("\nIOs: "+proname1+"["+str(numio1)+"]")
	print("50ms\t"+str(iola50_1))
	print("100ms\t"+str(iola100_1))
	print("150ms\t"+str(iola150_1))
	print("avg\t"+str(float('%.2f' % (iosum1/numio1*1000))))

fig = plt.figure(figsize=(16,8),dpi=100)

title = appname + " Io latency"

plt.title(title)
plt.plot(ioarr1, label=proname1)

if secondprj:
	plt.plot(ioarr2, label=proname2)

plt.xlabel("IOs")
plt.ylabel("time(ms)")
plt.legend(loc='upper right')
xlocs,xlables=plt.xticks()
ylocs,ylables=plt.yticks()
ylen=len(ylocs)
yfactor=980/ylen/25
ymax=ylocs[ylen-2]
ystep=(ylocs[ylen-1]-ylocs[ylen-2])/yfactor

if secondprj:
	plt.text(0,ymax+ystep,proname1+" ["+str(numio1)+"] "+rwstrt1)
	plt.text(0,ymax,proname2+" ["+str(numio2)+"] "+rwstrt2)
	plt.text(0,ymax-ystep,"latency "+proname1+"    "+proname2)
	plt.text(0,ymax-ystep*2,"50ms    "+str(iola50_1)+"    "+str(iola50_2))
	plt.text(0,ymax-ystep*3,"100ms   "+str(iola100_1)+"    "+str(iola100_2))
	plt.text(0,ymax-ystep*4,"150ms   "+str(iola150_1)+"    "+str(iola150_2))
	plt.text(0,ymax-ystep*5,"avg     "+str(float('%.2f' % (iosum1/numio1*1000)))+"    "+str(float('%.2f' % (iosum2/numio2*1000))))
else:
	plt.text(0,ymax+ystep,proname1+" ["+str(numio1)+"] "+rwstrt1)
	plt.text(0,ymax,"50ms    "+str(iola50_1))
	plt.text(0,ymax-ystep,"100ms   "+str(iola100_1))
	plt.text(0,ymax-ystep*2,"150ms   "+str(iola150_1))
	plt.text(0,ymax-ystep*3,"avg     "+str(float('%.2f' % (iosum1/numio1*1000))))

plt.show()
fig.savefig(appname+".png")

#start_row=2
#start_col=2

#workbook = xlwt.Workbook(encoding = 'ascii')
#worksheet = workbook.add_sheet('Gc_result')
#style = xlwt.Style.XFStyle()
#fnt = xlwt.Font()
#fnt.name = u'微软雅黑'
#style.font = fnt

#worksheet.write(start_row, start_col, label = '测试集合', style=style)
#worksheet.write(start_row, start_col+1, label = 'GC', style=style)
#worksheet.write(start_row, start_col+2, label = 'Total AVG', style=style)
#worksheet.write(start_row, start_col+3, label = 'Pause AVG', style=style)
#worksheet.write(start_row, start_col+4, label = 'BSCMS', style=style)
#worksheet.write(start_row, start_col+5, label = 'BPCMS', style=style)
#worksheet.write(start_row, start_col+6, label = 'CTMS', style=style)
#worksheet.write(start_row, start_col+7, label = 'ExCMS', style=style)
#worksheet.write(start_row, start_col+8, label = 'Spratio', style=style)

#worksheet.write(start_row+1, start_col, casename, style=style)
#worksheet.write(start_row+1, start_col+1, i, style=style)
#worksheet.write(start_row+1, start_col+2, "%.2f"%total_avg, style=style)
#worksheet.write(start_row+1, start_col+3, "%.2f"%pause_avg, style=style)
#worksheet.write(start_row+1, start_col+4, a1.get('BSCMS'), style=style)
#worksheet.write(start_row+1, start_col+5, a1.get('BPCMS'), style=style)
#worksheet.write(start_row+1, start_col+6, a1.get('CTMS'), style=style)
#worksheet.write(start_row+1, start_col+7, a1.get('ExCMS'), style=style)
#worksheet.write(start_row+1, start_col+8, "%.2f"%(a1.get('BSCMS')/a1.get('BPCMS')), style=style)

#workbook.save(casename+'.xls')
