import sqlite3
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import animation
import json

class RLKDB:

	def __init__(self, dbfile):
		self.db = dbfile
	
	def connect(self):
		self.conn = sqlite3.connect(self.db, check_same_thread = False)
		self.cursor = self.conn.cursor()
	
	def create_table(self, cmd):
		self.cursor.execute(cmd)
	
	def execute(self, cmd, data):
		self.cursor.execute(cmd, data)
	
	def fetch(self, cmd):
		self.cursor.execute(cmd)
		return self.cursor.fetchall()
	
	def executemany(self, cmd, data):
		self.cursor.executemany(cmd, data)
	
	def commit(self):
		self.conn.commit()
		
	def close(self):
		self.cursor.close()
		self.conn.close()

def testsqlite():
	db = RLKDB("dbs/033141181U000281.db")
	db.connect()
	#db.create_table('''
	#	create table IF NOT EXISTS deviceinfo
	#	(sn text, df text, frag float, stime datetime, seginfo text);
	#	''')
	#device = [(3,"x671483944","offline","50%",0.31,"2010-12-30 12:10:04"),
	#		(4,"x87364833048","online","57%",0.65,"2010-12-30 12:10:03"),
	#		(5,"523765544","offline","77%",0.32,"2010-12-30 12:10:06"),
	#		]
	#cmd = "insert into deviceinfo(sn, df, frag, stime, seginfo) values(?,?,?,?,?)"
	#db.execute('''insert into device values(1,'Ab12345678',"offline","60%",0.34,"2010-12-30 12:10:04")''')
	#db.execute(cmd, ("013445678","71%",0.55,"2010-12-30 12:10:05",str({"0":0, "512":0, "z":[]})))
	#db.executemany(cmd, device)
	#sel_cmd = "select count(*) from deviceinfo"
	sel_cmd = "select seginfo from deviceinfo"
	buf = db.fetch(sel_cmd)
	cnt = len(buf)
	#print(len(buf[0][0].replace("'", "\"")))
	print(cnt)
	#cnt = db.fetch(sel_cmd)[0][0]
	dy1 = 100
	fig2 = plt.figure()
	ims = []

	for i in range(cnt):
		bb = buf[i]
		cc = json.loads(bb[0].replace("'", "\""))["z"]
		dx1 = int(len(cc) / dy1)
		print(dx1)
		dd = np.array(cc).reshape(dx1,dy1)
		#print(cc)
		ims.append((plt.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), dd, norm=plt.Normalize(0, 30)),))
		#ax.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), bb)
		#print(json.loads(bb[0].replace("'", "\""))["z"])
		#break

	#fig2 = plt.figure()

	#ims = []
	#for add in np.arange(15):
	#	ims.append((plt.pcolor(segment['b'], segment['a'], segment['z'] + add, norm=plt.Normalize(0, 30)),))

	im_ani = animation.ArtistAnimation(fig2, ims, interval=200, repeat_delay=500,blit=True)
	plt.show()

	db.commit()
	db.close()

if __name__ == '__main__':
	testsqlite()

