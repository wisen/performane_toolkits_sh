import sqlite3

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
	db = RLKDB("./test1.db")
	db.connect()
	db.create_table(''' 
		create table IF NOT EXISTS deviceinfo
		(sn text, df text, frag float, stime datetime, seginfo text);
		''')
	#device = [(3,"x671483944","offline","50%",0.31,"2010-12-30 12:10:04"),
	#		(4,"x87364833048","online","57%",0.65,"2010-12-30 12:10:03"),
	#		(5,"523765544","offline","77%",0.32,"2010-12-30 12:10:06"),
	#		]
	cmd = "insert into deviceinfo(sn, df, frag, stime, seginfo) values(?,?,?,?,?)"
	#db.execute('''insert into device values(1,'Ab12345678',"offline","60%",0.34,"2010-12-30 12:10:04")''')
	db.execute(cmd, ("013445678","71%",0.55,"2010-12-30 12:10:05",str({"0":0, "512":0, "z":[]})))
	#db.executemany(cmd, device)
	
	#sel_cmd = "select * from device"
	#print(db.fetch(sel_cmd))
	
	db.commit()
	db.close()

if __name__ == '__main__':
	testsqlite()

