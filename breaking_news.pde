PGraphics pg;

int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;

float titleX = rightW;
boolean waitingForNews = false;
int marqueeCount = 0;

IntList colors = new IntList();
FloatList posx = new FloatList();
FloatList posy = new FloatList();
FloatList radiuses = new FloatList();
FloatList velx = new FloatList();
FloatList vely = new FloatList();

void settings() {
  float scaling = 10;
  while (ledsW * scaling > displayWidth) scaling--;
  size(int(ledsW * scaling), int(ledsH * scaling));
}

void setup() {
  pg = createGraphics(ledsW, ledsH);
  pg.noSmooth();
  thread("fetchPortugalData");
}

void draw() {
  if (newDataAvailable) {
    titleX = rightW;
    waitingForNews = false;
    newDataAvailable = false;
  }

  pg.beginDraw();
  
  drawLeftScreen(pg, 0, 0, leftW, ledsH);
  drawRightScreen(pg, leftW, 0, rightW, ledsH);

  pg.endDraw();

  background(0);
  noStroke();
  float cellDim = 0.9 * (width / (float) pg.width);
  pg.loadPixels();
  for (int y = 0; y < pg.height; y++) {
    float cY = map(y + 0.5, 0, pg.height, 0, height);
    for (int x = 0; x < pg.width; x++) {
      float cX = map(x + 0.5, 0, pg.width, 0, width);
      fill(pg.pixels[x + y * pg.width]);
      circle(cX, cY, cellDim);
    }
  }
}

void drawLeftScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.fill(20, 60); // Alpha for trails effect
  pg.noStroke();
  pg.rect(0, 0, w, h);

  if (totalApiResults > 0) {
    for (int i=0; i<totalApiResults; i++) {
      float currentSpeed = map(newsImpactScore, 0, 100, 0.5, 3);
      float px = posx.get(i) + velx.get(i) * currentSpeed;
      float py = posy.get(i) + vely.get(i) * currentSpeed;
      float d = radiuses.get(i);
      float r = d / 2;
      
      if (px - r < 0) {
        px = r;
        velx.set(i, abs(velx.get(i)));
      } else if (px + r > w) {
        px = w - r;
        velx.set(i, -abs(velx.get(i)));
      }
      
      if (py - r < 0) {
        py = r;
        vely.set(i, abs(vely.get(i)));
      } else if (py + r > h) {
        py = h - r;
        vely.set(i, -abs(vely.get(i)));
      }
      
      posx.set(i, px);
      posy.set(i, py);
      
      pg.fill(colors.get(i));
      pg.circle(px, py, d);
    }
  }
  pg.popMatrix();
}

void drawRightScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.clip(0, 0, w, h);
  pg.fill(12);
  pg.noStroke();
  pg.rect(0, 0, w, h);
  pg.fill(color(map(newsImpactScore,0,100,0,255), map(newsImpactScore,0,100,255,0), 0));
  pg.textSize(12);
  pg.textAlign(LEFT, CENTER);

  float titleW = pg.textWidth(currentTitle);
  float titleSpeed = 1.0;
  pg.text(currentTitle.toUpperCase(), titleX, h / 2 - 1);

  if (!waitingForNews) {
    titleX -= titleSpeed;
    if (titleX < -titleW*1.2) {
      marqueeCount++;
      if (marqueeCount >= 3) {
        titleX = w;
        waitingForNews = true;
        marqueeCount = 0;
        thread("fetchPortugalData");
      } else {
        titleX = w;
      }
    }
  }

  pg.noClip();
  pg.popMatrix();
}
