import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # needed for 3D plots
import numpy as np

target = np.array([-1.095, -0.262, 0.8895])

points_x = []
points_y = []
points_z = []

dists = []

num_points = 0

estimated_target_x = []
estimated_target_y = []
estimated_target_z = []

prev_dist = 0

class KalmanFilter1D:
    def __init__(self, initial: float, process_noise: float, measurement_noise: float):
        """
        :param initial: initial distance estimate
        :param process_noise: Q, how much the distance can change naturally
        :param measurement_noise: R, how noisy the measurements are
        """
        self.x = initial      # estimated value
        self.p = 1.0          # estimate uncertainty
        self.q = process_noise
        self.r = measurement_noise

    def update(self, measurement: float) -> float:
        """
        Update the filter with a new measurement and return the filtered estimate
        """
        # Prediction step
        self.p = self.p + self.q

        # Kalman gain
        k = self.p / (self.p + self.r)

        # Update estimate
        self.x = self.x + k * (measurement - self.x)

        # Update uncertainty
        self.p = (1 - k) * self.p

        return self.x

def valid_pts(p):
    ab = p[1] - p[0]
    ac = p[2] - p[0]
    ad = p[3] - p[0]

    ab = ab / np.linalg.norm(ab)
    ac = ac / np.linalg.norm(ac)
    ad = ad / np.linalg.norm(ad)

    if abs(np.dot(ab, ac)) > 0.75 or abs(np.dot(ab, ac)) < 0.25:
        return False

    cross = np.cross(ab, ac)
    if abs(np.dot(cross, ad)) < 0.25:
        return False

    return True

with open("points2.txt") as file:
    f = KalmanFilter1D(1.56, 1, 0.5)
    for line in file:
        if line[0] == "#":
            continue
        x, y, z, d = line.split(" ")
        # d = f.update(float(d))
        position = np.array([float(x), float(y), float(z)])
        direction = (target - position) / np.linalg.norm(target - position)

        estimated_target_x.append(direction[0] * float(d))
        estimated_target_y.append(direction[1] * float(d))
        estimated_target_z.append(direction[2] * float(d))

        delta = float(d) - prev_dist
        print(delta)
        print(abs(np.linalg.norm(position - target) - float(d)))
        print("====")
        # if abs(np.linalg.norm(position - target) - float(d)) > 0.2:
        #     continue
        prev_dist = float(d)

        points_x.append(float(x))
        points_y.append(float(y))
        points_z.append(float(z))
        dists.append(float(d))

        num_points += 1


evaluated_x = []
evaluated_y = []
evaluated_z = []
avg = np.array([0, 0, 0])
cnt = 0

while cnt < 50:
    chosen_pts = np.random.choice(num_points, size=5, replace=False)
    p = []
    d = []
    for i in chosen_pts:
        p.append(np.array([points_x[i], points_y[i], points_z[i]]))
        d.append(dists[i])

    if not valid_pts(p[1:]):
        continue

    anchor_pos_sq = p[0][0] ** 2 + p[0][1] ** 2 + p[0][2] ** 2
    A_raw = []
    b_raw = []
    for j in range(1, 5):
        A_raw.append(p[j] - p[0])
        b_raw.append(0.5 * (d[0] ** 2 - d[j] ** 2 + p[j][0] ** 2 + p[j][1] ** 2 + p[j][2] ** 2 - anchor_pos_sq))
    
    A = np.array(A_raw)
    b = np.array(b_raw)
    At = A.T

    result = np.linalg.inv(At @ A) @ At @ b
    print(result)
    avg = avg + result
    cnt += 1
    evaluated_x.append(avg[0] / cnt)
    evaluated_y.append(avg[1] / cnt)
    evaluated_z.append(avg[2] / cnt)


# num_least_square_points = 4
# for i in range(num_points - num_least_square_points):
#     anchor = np.array([points_x[i], points_y[i], points_z[i]])
#     anchor_pos_sq = points_x[i] ** 2 + points_y[i] ** 2 + points_z[i] ** 2
#     A_raw = []
#     b_raw = []
#     for j in range(i + 1, i + num_least_square_points + 1):
#         vec = np.array([points_x[j], points_y[j], points_z[j]])
#         A_raw.append(vec - anchor)
#         b_raw.append(0.5 * (dists[i] ** 2 - dists[j] ** 2 + points_x[j] ** 2 + points_y[j] ** 2 + points_z[j] ** 2 - anchor_pos_sq))

#     A = np.array(A_raw)
#     b = np.array(b_raw)

#     At = A.T

#     result = np.linalg.inv(At @ A) @ At @ b
#     avg = avg + result
#     cnt += 1
#     if abs(avg[0] / cnt) > 20 or abs(avg[1] / cnt) > 20 or abs(avg[2] / cnt) > 20:
#         continue
#     evaluated_x.append(avg[0] / cnt)
#     evaluated_y.append(avg[1] / cnt)
#     evaluated_z.append(avg[2] / cnt)


error = np.linalg.norm((avg / cnt) - target)
print(f"error {error}")

# Create figure
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')

# Plot points
ax.scatter(points_x, points_z, points_y, color='blue', marker='o')
ax.scatter(evaluated_x, evaluated_z, evaluated_y, color='red', marker='x')
ax.scatter(evaluated_x[-1], evaluated_z[-1], evaluated_y[-1], color='blue', marker='x')
ax.scatter(target[0], target[2], target[1], color='green', marker='x')

# Labels
ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_zlabel('Z')

plt.show()