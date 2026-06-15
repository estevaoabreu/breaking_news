# Breaking News

This project was developed for the **"Generative Design"** course unit of the **Master's in Design and Multimedia** at the **Faculty of Sciences and Technology of the University of Coimbra (FCTUC)**.

**Authors:**

- Estêvão Abreu
- Mariana Silva

---

## About The Project

This is a live generative design system that visualizes breaking news. It fetches the latest news from Coimbra and Portugal using the **World News API**, and uses the **Google Gemini API** to deeply evaluate the social impact, economic impact, and category of the headlines.

The display is split into two visual components representing a low-resolution LED screen aesthetic:

- **Left Screen (Ambient Generative Canvas):** A generative visualization representing the news landscape. It features organic, flocking metaballs (blobs) that drift and cluster together based on their shared news category. The color of each blob represents its social impact (from red to green), while its radius represents economic impact. A high-resolution digital clock overlays the scene, dynamically inverting its color over the fluid shapes.

- **Right Screen (Digital Terminal):** A retro terminal typewriter effect that prints the latest breaking news headlines character by character, holding the fully typed headline on screen for a brief pause before cycling to the next breaking article.

---

## Setup & Installation

1. Create a file named `api_keys.json` in the root folder of this project.
2. Add your API keys for World News API and Google Gemini in the following format:

   ```json
   {
     "world_news_api_key": "YOUR_WORLD_NEWS_API_KEY_HERE",
     "gemini_api_key": "YOUR_GEMINI_API_KEY_HERE"
   }
   ```

3. Open `breaking_news.pde` in **Processing 4** and hit Run.

---

## Tech Stack

- **Processing 4 (Java)**: Core graphics, networking, and threading engine.
- **World News API**: Live article aggregation.
- **Google Gemini API**: AI-powered semantic analysis (categorization and impact scoring).
