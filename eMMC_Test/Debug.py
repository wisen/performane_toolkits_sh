import inspect

class Debug:

	def get_current_function_name(self):  
		return inspect.stack()[1][3]
	
	def func(self):
		print("%s.%s ******", self.__class__.__name__, self.get_current_function_name())	
		
if __name__ == "__main__":
	d = Debug()
	d.func()
	