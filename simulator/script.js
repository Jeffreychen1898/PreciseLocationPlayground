const TRACKER_SIZE = 20;

class Tracker {
  constructor(x, y, target=false) {
    this.x = x;
    this.y = y;
    this.target = target;
  }
  
  render() {
    if (this.target) {
      fill(255, 255, 0);
    } else {
      fill(255, 0, 0);
    }
    ellipse(this.x, this.y, TRACKER_SIZE, TRACKER_SIZE);
  }
  
  getx() {
    return this.x + random(-2, 2);
  }
  
  gety() {
    return this.y + random(-2, 2);
  }
  
  onHover() {
    const dx = this.x - mouseX;
    const dy = this.y - mouseY;
    return sqrt(dx * dx + dy * dy) < TRACKER_SIZE/2;
  }
}

const trackers = [
  new Tracker(100, 100),
  new Tracker(200, 200),
  new Tracker(100, 200),
  new Tracker(200, 100),
  new Tracker(300, 300, true)
];

let selected = -1;

let cache = null;
let cacheSize = 0;

function evaluateTarget(trackers, target) {
  const anchor = trackers[0];
  const dr = dist(anchor.x, anchor.y, target.x, target.y) + random(-10, 10);
  let A_raw = [];
  let b_raw = [];
  for (let i=1;i<trackers.length;++i) {
    const di = dist(trackers[i].getx(), trackers[i].gety(), target.getx(), target.gety()) + random(-2, 2);
    A_raw.push([1 * (trackers[i].getx() - anchor.getx()), 1 * (trackers[i].gety() - anchor.gety())]);
    const xi = trackers[i].getx();
    const yi = trackers[i].gety();
    b_raw.push([0.5 * (dr * dr - di * di + xi * xi + yi * yi - anchor.getx() * anchor.getx() - anchor.gety() * anchor.gety())]);
  }
  const A = math.matrix(A_raw);
  const b = math.matrix(b_raw);
  
  const At = math.transpose(A);
  const inv = math.inv(math.multiply(At, A));
  const sln = math.multiply(math.multiply(inv, At), b);

  const target_coords = math.subset(sln, math.index([0, 1], 0)).valueOf().flat();
  fill(255, 255, 255);
  ellipse(target_coords[0], target_coords[1], 5, 5);
  
  cache.add(createVector(target_coords[0], target_coords[1]));
  cacheSize ++;

  const avg = cache.copy();
  avg.div(cacheSize);
  fill(255, 0, 255);
  ellipse(avg.x, avg.y, 5, 5);
}

function setup() {
  createCanvas(400, 400);
  cache = createVector(0, 0);
}

function draw() {
  background(0);
  for (const tracker of trackers) {
    tracker.render();
  }
  
  if (selected > -1) {
    trackers[selected].x = mouseX;
    trackers[selected].y = mouseY;
  }
  
  evaluateTarget([trackers[0], trackers[1], trackers[2], trackers[3]], trackers[4]);
}

function mousePressed() {
  for (let i=0;i<trackers.length;++i) {
    if (trackers[i].onHover()) {
      selected = i;
      return;
    }
  }
}

function mouseReleased() {
  selected = -1;
}

function keyPressed() {
  if (key == 'q') {
    cache = createVector(0, 0);
    cacheSize = 0;
  }
}
