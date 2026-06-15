PGraphics pg;

int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;
int marqueeIterations = 1;
int blobLimit = 100;

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
FloatList baseSpeeds = new FloatList();

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
      if (posx.size() >= blobLimit) {
        posx.clear(); posy.clear(); radiuses.clear();
        velx.clear(); vely.clear(); hues.clear(); deformations.clear(); baseSpeeds.clear();
      }
      hues.append(newBlobHue);
      posx.append(newBlobPx);
      posy.append(newBlobPy);
      radiuses.append(newBlobRad);
      velx.append(newBlobVx);
      vely.append(newBlobVy);
      deformations.append(newBlobDeform);
      baseSpeeds.append(newBlobSpeed);
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
    // 1. Calculate Boids acceleration (Flocking)
    FloatList accx = new FloatList();
    FloatList accy = new FloatList();
    for (int i=0; i<totalApiResults; i++) {
        accx.append(0); accy.append(0);
    }
    
    float separationDist = 20.0f; 
    float perceptionDist = 40.0f;
    
    for (int i=0; i<totalApiResults; i++) {
      float steerX = 0, steerY = 0;
      float alignX = 0, alignY = 0;
      float cohX = 0, cohY = 0;
      int countSep = 0, countAlign = 0, countCoh = 0;
      
      float pxi = posx.get(i); float pyi = posy.get(i);
      
      for (int j=0; j<totalApiResults; j++) {
        if (i == j) continue;
        float pxj = posx.get(j); float pyj = posy.get(j);
        float d = dist(pxi, pyi, pxj, pyj);
        
        if (d > 0 && d < separationDist) {
          float diffX = pxi - pxj;
          float diffY = pyi - pyj;
          diffX /= d; diffY /= d;
          steerX += diffX; steerY += diffY;
          countSep++;
        }
        if (d > 0 && d < perceptionDist) {
          alignX += velx.get(j); alignY += vely.get(j);
          countAlign++;
          cohX += pxj; cohY += pyj;
          countCoh++;
        }
      }
      
      float ax = 0, ay = 0;
      if (countSep > 0) {
        steerX /= countSep; steerY /= countSep;
        ax += steerX * 0.05f;
        ay += steerY * 0.05f;
      }
      if (countAlign > 0) {
        alignX /= countAlign; alignY /= countAlign;
        ax += (alignX - velx.get(i)) * 0.01f;
        ay += (alignY - vely.get(i)) * 0.01f;
      }
      if (countCoh > 0) {
        cohX /= countCoh; cohY /= countCoh;
        float desiredVX = cohX - pxi; float desiredVY = cohY - pyi;
        float speed = dist(0, 0, desiredVX, desiredVY);
        if (speed > 0) { desiredVX /= speed; desiredVY /= speed; }
        ax += (desiredVX - velx.get(i)) * 0.005f;
        ay += (desiredVY - vely.get(i)) * 0.005f;
      }
      
      accx.set(i, ax);
      accy.set(i, ay);
    }

    // 2. Update Physics and Hue gradients
    for (int i=0; i<totalApiResults; i++) {
      float vx = velx.get(i) + accx.get(i);
      float vy = vely.get(i) + accy.get(i);
      
      float speedMag = dist(0, 0, vx, vy);
      float mySpeed = baseSpeeds.get(i);
      if (speedMag > 0) {
        vx = (vx / speedMag) * mySpeed;
        vy = (vy / speedMag) * mySpeed;
      }
      velx.set(i, vx); vely.set(i, vy);
      
      float px = posx.get(i) + vx;
      float py = posy.get(i) + vy;
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
          
          float pulse = 1.0f + 0.15f * sin(millis() * 0.005f + i);
          float radius = radiuses.get(i) * pulse * 3.0f; // Scale up for metaball overlap
          
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
