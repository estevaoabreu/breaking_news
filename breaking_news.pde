PGraphics pg;

int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;
int marqueeIterations = 1;

float titleX = rightW;
boolean waitingForNews = false;
int marqueeCount = 0;
boolean clearLeftScreen = false;

FloatList hues = new FloatList();
FloatList posx = new FloatList();
FloatList posy = new FloatList();
FloatList radiuses = new FloatList();
FloatList velx = new FloatList();
FloatList vely = new FloatList();
FloatList deformations = new FloatList();

void settings() {
  float scaling = 10;
  while (ledsW * scaling > displayWidth) scaling--;
  size(int(ledsW * scaling), int(ledsH * scaling));
}

void setup() {
  pg = createGraphics(ledsW, ledsH);
  pg.noSmooth();
  pg.beginDraw();
  pg.background(12);
  pg.endDraw();
  thread("fetchPortugalData");
}

void draw() {
  if (newDataAvailable) {
    titleX = rightW;
    waitingForNews = false;
    newDataAvailable = false;
    
    if (spawnNewBlob) {
      if (posx.size() >= 200) {
        posx.clear(); posy.clear(); radiuses.clear();
        velx.clear(); vely.clear(); hues.clear(); deformations.clear();
      }
      hues.append(newBlobHue);
      posx.append(newBlobPx);
      posy.append(newBlobPy);
      radiuses.append(newBlobRad);
      velx.append(newBlobVx);
      vely.append(newBlobVy);
      deformations.append(newBlobDeform);
      totalApiResults = posx.size();
      spawnNewBlob = false;
    }
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

  // Clear every frame since these are discrete objects, not trails
  pg.fill(12);
  pg.noStroke();
  pg.rect(0, 0, w, h);

  if (totalApiResults > 0) {
    // 1. Update Physics and Hue gradients
    for (int i=0; i<totalApiResults; i++) {
      float px = posx.get(i) + velx.get(i);
      float py = posy.get(i) + vely.get(i);
      float r = radiuses.get(i);
      
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
      
      float hVal = hues.get(i) + 0.001f;
      if (hVal > 1.0f) hVal -= 1.0f;
      hues.set(i, hVal);
    }
    
    // 2. Render Metaballs
    pg.loadPixels();
    for (int py = 0; py < h; py++) {
      for (int px = 0; px < w; px++) {
        float sum = 0;
        float rSum = 0;
        float gSum = 0;
        float bSum = 0;
        
        for (int i = 0; i < totalApiResults; i++) {
          float bx = posx.get(i);
          float by = posy.get(i);
          float radius = radiuses.get(i) * 3.0f; // Scale up for metaball overlap
          
          float dx = px - bx;
          float dy = py - by;
          
          float blobAngle = atan2(dy, dx);
          float time = millis() * 0.001f;
          float distFactor = 
              sin(blobAngle * 2.0f + time * 1.5f + i) * 0.5f +
              cos(blobAngle * 3.0f - time * 2.0f + i) * 0.3f +
              sin(blobAngle * 5.0f + time * 1.2f + i) * 0.2f;
              
          float distortion = 1.0f + deformations.get(i) * distFactor;
          float distSq = (dx*dx + dy*dy) * distortion;
          
          if (distSq > 0) {
            float influence = (radius * radius) / distSq;
            sum += influence;
            
            if (influence > 0.01f) {
              int c = java.awt.Color.HSBtoRGB(hues.get(i), 1.0f, 1.0f);
              float rCol = (c >> 16) & 0xFF;
              float gCol = (c >> 8) & 0xFF;
              float bCol = c & 0xFF;
              
              rSum += rCol * influence;
              gSum += gCol * influence;
              bSum += bCol * influence;
            }
          }
        }
        
        if (sum >= 1.0f) {
          int rCol = min(255, (int)(rSum / sum));
          int gCol = min(255, (int)(gSum / sum));
          int bCol = min(255, (int)(bSum / sum));
          
          int pIndex = (int)(px + x) + (int)(py + y) * pg.width;
          pg.pixels[pIndex] = color(rCol, gCol, bCol);
        }
      }
    }
    pg.updatePixels();
  }
  pg.popMatrix();
}

void drawRightScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.clip(0, 0, w, h);
  pg.fill(12);
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
      if (marqueeCount >= marqueeIterations) {
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
