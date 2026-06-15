# Breaking News

This project was developed for the **"Generative Design"** course unit of the **Master's in Design and Multimedia** at the **Faculty of Sciences and Technology of the University of Coimbra (FCTUC)**.

**Authors:**

- Estêvão Abreu
- Mariana Silva

---

## About The Project

This is a live generative design system that visualizes breaking news. It fetches the latest news from Coimbra and Portugal using **NewsAPI**, and uses the **Google Gemini API** to evaluate the social and economic impact of the headlines.

The display is split into two screens:

- **Left Screen (Abstract Data):** A generative visualization representing the volume of recent news with dynamic colored blocks.
- **Right Screen (Ticker):** A scrolling marquee displaying the latest breaking news headlines.

---

## Setup & Installation

1. Create a file named `api_keys.json` in the root folder of this project.
2. Add your API keys for NewsAPI and Google Gemini in the following format:

   ```json
   {
     "news_api_key": "YOUR_NEWSAPI_KEY_HERE",
     "gemini_api_key": "YOUR_GEMINI_API_KEY_HERE"
   }
   ```

3. Open `breaking_news.pde` in **Processing 4** and hit Run.

---

## Screenshots

---

## Tech Stack

- **Processing 4 (Java)**
- **NewsAPI**
- **Google Gemini API**
