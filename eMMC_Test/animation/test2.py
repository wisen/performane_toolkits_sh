import numpy as np
import matplotlib.pyplot as plt

n_points = 10
aa = np.linspace(-5, 5, n_points)
bb = np.linspace(-1.5, 1.5, n_points)



def cost(a, b):
    return a + b

z = []
for a in aa:
    for b in bb:
        z.append(cost(a, b))

z = np.reshape(z, [len(aa), len(bb)])

print(type(aa))
print(aa)
print(type(bb))
print(bb)
print(type(z))
print(z)

fig, ax = plt.subplots()
im = ax.pcolormesh(aa, bb, z)
fig.colorbar(im)

ax.axis('tight')
plt.show()
