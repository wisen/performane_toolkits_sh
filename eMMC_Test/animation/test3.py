import numpy as np
import matplotlib.pyplot as plt
from matplotlib import animation

segment={'a':[1,2,3],'b':[1,2,3,4,5],'z':[1,1,1,2,2,2,2,1,1,1,1,3,3,4,4]}
segment['z']=np.reshape(segment['z'],[3,5])

print(type(segment['a']))
print(segment['a'])
print(segment['z'])

#fig, ax = plt.subplots()
#im = ax.pcolormesh(segment['b'], segment['a'], segment['z'])
#im = ax.pcolor(segment['b'], segment['a'], segment['z'])
#fig.colorbar(im)

#ax.axis('tight')

# animation function.  This is called sequentially
#def animate(i):
#    data = np.random.random((segment['b'], segment['a']))
#    im.set_array(data)
#    return [im]

#anim = animation.FuncAnimation(fig, animate, frames=200, interval=60, blit=True)
#plt.show()

fig2 = plt.figure()

#x = np.arange(-9, 10)
#y = np.arange(-9, 10).reshape(-1, 1)
#base = np.hypot(x, y)
ims = []
for add in np.arange(15):
    ims.append((plt.pcolor(segment['b'], segment['a'], segment['z'] + add, norm=plt.Normalize(0, 30)),))

im_ani = animation.ArtistAnimation(fig2, ims, interval=500, repeat_delay=1000,
                                   blit=True)
# To save this second animation with some metadata, use the following command:
# im_ani.save('im.mp4', metadata={'artist':'Guido'})

plt.show()