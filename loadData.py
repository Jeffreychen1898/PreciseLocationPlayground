import numpy as np

class Dataset:
    def __init__(self):
        self.datapoint_coord_x = []
        self.datapoint_coord_y = []
        self.datapoint_coord_z = []
        self.datapoint_distance = []
        self.target = {"x": 0, "y": 0, "z": 0}

    def load(self, filename):
        with open(filename, 'r') as file:
            for line in file:
                self.loadLine(line.strip())

    def size(self):
        return len(self.datapoint_distance)

    def getPoint(self, index):
        coordinate = [
            self.datapoint_coord_x[index],
            self.datapoint_coord_y[index],
            self.datapoint_coord_z[index]
        ]
        return {
            "coord": np.array(coordinate),
            "distance": self.datapoint_distance[index]
        }

    def loadLine(self, line):
        if line.startswith("#"):
            pass
        elif line.startswith("(") and line.endswith(")"):
            self.parseTarget(line)
        else:
            self.parseDatapoint(line)

    def parseTarget(self, line):
        data = line[1:-2].split(",")
        if len(data) != 3:
            raise Exception("Invalid syntax while parsing target!")

        self.target["x"] = float(data[0].strip())
        self.target["y"] = float(data[1].strip())
        self.target["z"] = float(data[2].strip())

    def parseDatapoint(self, line):
        data = line.split(",")
        if len(data) != 4:
            raise Exception("Invalid syntax while parsing datapoint!")

        self.datapoint_coord_x.append(float(data[0].strip()))
        self.datapoint_coord_y.append(float(data[1].strip()))
        self.datapoint_coord_z.append(float(data[2].strip()))
        self.datapoint_distance.append(float(data[3].strip()))

def convertToGridData(x_coords, y_coords, z_coords, dists):
    if len(x_coords) != len(y_coords) or len(y_coords) != len(z_coords) or len(z_coords) != len(dists):
        raise Exception("Unexpected error!")

    GRID_SIZE = 0.3

    groups = dict()
    for i in range(len(x_coords)):
        x, y, z, d = x_coords[i], y_coords[i], z_coords[i], dists[i]
        group_index = (x // GRID_SIZE, y // GRID_SIZE, z // GRID_SIZE)
        if group_index not in groups:
            groups[group_index] = []

        groups[group_index].append([x, y, z, d])

    aggregated_data = []

    for _, data_arr in groups.items():
        data_sum = [0, 0, 0, 0]
        for datapoint in data_arr:
            data_sum[0] += datapoint[0]
            data_sum[1] += datapoint[1]
            data_sum[2] += datapoint[2]
            data_sum[3] += datapoint[3]

        aggregated_data.append({
            "x": data_sum[0] / len(data_arr),
            "y": data_sum[1] / len(data_arr),
            "z": data_sum[2] / len(data_arr),
            "distance": data_sum[3] / len(data_arr)
        })

    return aggregated_data

def triangulateTarget(anchor, points):
    anchor_vector = np.array([anchor["x"], anchor["y"], anchor["z"]])
    anchor_pos_sq = np.dot(anchor_vector, anchor_vector)

    A_raw = []
    b_raw = []
    for point in points:
        vec = np.array([point["x"], point["y"], point["z"]])
        vec_sq = np.dot(vec, vec)
        A_raw.append(vec - anchor_vector)
        b_raw.append(0.5 * (anchor["distance"] ** 2 - point["distance"] ** 2 + vec_sq - anchor_pos_sq))

    A = np.array(A_raw)
    b = np.array(b_raw)

    At = A.T

    target = np.linalg.inv(At @ A) @ At @ b

    return {
        "x": target[0],
        "y": target[1],
        "z": target[2]
    }