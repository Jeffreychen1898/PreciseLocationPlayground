import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # needed for 3D plots

from loadData import *

ds = Dataset()

def main():
    ds.load("points2.txt")

    new_distance_arr = []
    new_error_arr = []
    distance_arr = []
    error_arr = []

    aggregated_data = convertToGridData(
        ds.datapoint_coord_x,
        ds.datapoint_coord_y,
        ds.datapoint_coord_z,
        ds.datapoint_distance
    )

    target = np.array([
        ds.target["x"],
        ds.target["y"],
        ds.target["z"]
    ])
    for datapoint in aggregated_data:
        position = np.array([datapoint["x"], datapoint["y"], datapoint["z"]])
        dist = np.linalg.norm(target - position)
        new_distance_arr.append(dist)
        new_error_arr.append(datapoint["distance"] - dist)

    for i in range(ds.size()):
        datapoint = ds.getPoint(i)
        target = np.array([
            ds.target["x"],
            ds.target["y"],
            ds.target["z"]
        ])

        true_distance = np.linalg.norm(target - datapoint["coord"])
        reported_distance = datapoint["distance"]

        distance_arr.append(true_distance)
        error_arr.append((reported_distance - true_distance))

    plt.scatter(distance_arr, error_arr, color='red')
    plt.scatter(new_distance_arr, new_error_arr, color='blue')
    plt.show()

if __name__ == "__main__":
    main()