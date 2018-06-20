import sqlite3
import matplotlib.pyplot as plt

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
	#	(sn text, df text, ratio float, stime datetime, seginfo text);
	#	''')

	# sel_cmd = "select seginfo from deviceinfo"
	# buf = db.fetch(sel_cmd)
	# cnt = len(buf)
	# print(cnt)
	# dy1 = 100
	# fig2 = plt.figure()
	# ims = []

	# for i in range(cnt):
		# bb = buf[i]
		# cc = json.loads(bb[0].replace("'", "\""))["z"]
		# dx1 = int(len(cc) / dy1)
		# print(dx1)
		# dd = np.array(cc).reshape(dx1,dy1)
		# ims.append((plt.pcolor(np.arange(0, dy1 + 1, 1), np.arange(dx1, -1, -1), dd, norm=plt.Normalize(0, 30)),))

	# im_ani = animation.ArtistAnimation(fig2, ims, interval=200, repeat_delay=500,blit=True)
	# plt.show()

	sel_cmd = "select df,ratio from deviceinfo"
	buf = db.fetch(sel_cmd)
	cnt = len(buf)
	print(cnt)
	print(type(buf))
	print(buf)
	fig = plt.figure()
	a = []
	b = []
	for i in range(cnt):
		a.append(buf[i][0])
		b.append(buf[i][1])
	line1 = plt.plot(a)
	#line1.set_color('r')
	line2 = plt.plot(b)
	#line2.set_color('g')
	plt.show()

	db.commit()
	db.close()

if __name__ == '__main__':
	testsqlite()

