import threading
import time
import Debug as d

class RLKThread(threading.Thread):
	def __init__(self, name, target, args, kwargs, stopevt, delay=0):
		threading.Thread.__init__(self)
		self.stopevt = stopevt
		self.name = name
		self.target = target
		self.args = args
		self.kwargs = kwargs
		self.delay = delay
		d.init()

	def Eventrun(self):
		while not self.stopevt.isSet():
			self.target(self.args, self.kwargs)
			if self.delay:
				time.sleep(self.delay)
		d.d('stoped')

	def run(self):
		self.Eventrun()

def testfunc(args, kwargs):
		print("I'm working function "+str(kwargs)+repr(threading.currentThread())+' alive\n')
		
def testthread():
	stopevt = threading.Event()
	A = RLKThread(stopevt=stopevt, name='subthreadA', target=testfunc, args=" ", kwargs={"sn":"123456","s":"online"})
	B = RLKThread(stopevt=stopevt, name='subthreadB', target=testfunc, args=" ", kwargs={"sn":"343434","s":"offline"})
	print(repr(threading.currentThread())+'alive\n')
	A.start()
	B.start()
	print(threading.enumerate())
	time.sleep(5)
	print(repr(threading.currentThread())+'send stop signal\n')
	stopevt.set()
	print(threading.enumerate())
	time.sleep(5)
	print("clear..")
	stopevt.clear()
	#A.start()
	#B.start()
	time.sleep(5)
	A.join()
	B.join()
	print(repr(threading.currentThread())+'stoped\n')
	
if __name__ =='__main__':
	testthread()