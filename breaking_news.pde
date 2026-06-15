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
  pg.background(0);

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
  pg.fill(20);
  pg.noStroke();
  pg.rect(0, 0, w, h);

  if (totalApiResults > 0) {
    for (int i=0; i<totalApiResults; i++) {
      if (random(1)>0.5)
        radiuses.add(i, map(newsImpactScore,0,100,0,3));
      else radiuses.sub(i, map(newsImpactScore,0,100,0,3));
      pg.fill(colors.get(i));
      pg.circle(posx.get(i), posy.get(i), radiuses.get(i));
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
  pg.fill(245);
  pg.textSize(12);
  pg.textAlign(LEFT, CENTER);

  float titleW = pg.textWidth(currentTitle);
  float titleSpeed = 1.0;
  pg.text(currentTitle.toUpperCase(), titleX, h / 2 - 1);

  if (!waitingForNews) {
    titleX -= titleSpeed;
    if (titleX < -titleW*1.1) {
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
