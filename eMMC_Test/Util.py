import shutil
import os
import Debug as d

def copyfile(srcfile, dstfile):
    if not os.path.isfile(srcfile):
        print("%s not exist!" + srcfile)
    else:
        fpath, fname = os.path.split(dstfile)
        if not os.path.exists(fpath):
            os.makedirs(fpath)
        shutil.copyfile(srcfile, dstfile)
        d.d("copy " + srcfile + "-> " + dstfile)