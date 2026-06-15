PGraphics pg;

// Screen Dimensions
int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;

// Marquee State
float titleX = 75; // Initial position (right edge)
int passesCompleted = 0;
boolean waitingForNews = false;

void settings() {
  // Find the larger scaling that fits your screen
  float scaling = 10;
  while (ledsW * scaling > displayWidth) scaling--;
  size(int(ledsW * scaling), int(ledsH * scaling));
}

void setup() {
  pg = createGraphics(ledsW, ledsH);
  pg.noSmooth(); // Disable anti-aliasing to make tiny text crisp
  
  // Kickstart background data collection
  thread("fetchPortugalData");
}

void draw() {
  // Check if new data is available
  if (newDataAvailable) {
    titleX = rightW;
    passesCompleted = 0;
    waitingForNews = false;
    newDataAvailable = false;
  }

  // Render content to offscreen graphics
  pg.beginDraw();
  pg.background(0);
  
  // Draw the two facades
  drawLeftScreen(pg, 0, 0, leftW, ledsH);
  drawRightScreen(pg, leftW, 0, rightW, ledsH);
  
  pg.endDraw();
  
  // Now draw the LED preview to the main screen
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

// Function to draw the left part of the screen
void drawLeftScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  
  // Background for left side
  pg.fill(20);
  pg.noStroke();
  pg.rect(0, 0, w, h);
  
  // Placeholder visual for the left screen
  if (totalApiResults > 0) {
    float piecesSize = (w*h)/totalApiResults;
    for (int i=0; i<totalApiResults;i++){
        pg.fill(cores.get(i));
      pg.square(posx.get(i),posy.get(i),piecesSize);
    }
  }
  
  pg.popMatrix();
}

// Function to draw the right part of the screen, displaying only the news title
void drawRightScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.clip(0, 0, w, h); // Prevent text from clipping onto the left screen
  
  // Background for right side
  pg.fill(12);
  pg.noStroke();
  pg.rect(0, 0, w, h);
  
  // Render Breaking News Headline (Scrolling Marquee)
  pg.fill(245);
  pg.textSize(12); // Make the text larger since it's the only thing on this screen
  pg.textAlign(LEFT, CENTER);
  
  float titleW = pg.textWidth(currentTitle);
  float titleSpeed = 1.0; // pixels per frame
  
  // Draw the title
  pg.text(currentTitle.toUpperCase(), titleX, h / 2 - 1); // Center vertically
  
  // Update position unless waiting for network
  if (!waitingForNews) {
    titleX -= titleSpeed;
    
    // Check if the title has fully scrolled off the left edge
    if (titleX < -titleW*1.1) {
      titleX = w; // reset to right edge
      passesCompleted++;
      
      // If it passed 3 times, trigger fetch
      if (passesCompleted >= 1) {
        waitingForNews = true;
        thread("fetchPortugalData");
      }
    }
  }
  
  pg.noClip();
  pg.popMatrix();
}
