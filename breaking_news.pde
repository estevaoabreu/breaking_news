PGraphics pg;

int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;

float titleX = rightW;
boolean waitingForNews = false;

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
  for (int y = 0; y < pg.height; y++) {
    float cY = map(y + 0.5, 0, pg.height, 0, height);
    for (int x = 0; x < pg.width; x++) {
      float cX = map(x + 0.5, 0, pg.width, 0, width);
      fill(pg.get(x, y));
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
    float piecesSize = (w*h)/totalApiResults;
    for (int i=0; i<totalApiResults; i++) {
      pg.fill(cores.get(i));
      pg.square(posx.get(i), posy.get(i), piecesSize);
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
      titleX = w;
      waitingForNews = true;
      thread("fetchPortugalData");
    }
  }

  pg.noClip();
  pg.popMatrix();
}
