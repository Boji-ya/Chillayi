import * as functions from "firebase-functions";
import axios from "axios";
import Parser from "rss-parser";

const parser = new Parser();

export const getNews = functions.https.onRequest(
  async (req, res) => {
    try {
      const rssUrl =
        "https://www.chiayi.gov.tw/RSS2.aspx?n=454";

      const response = await axios.get(rssUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0",
        },
      });

      const feed = await parser.parseString(
        response.data
      );

      const news = feed.items.map((item) => ({
        title: item.title ?? "",
        description:
          item.contentSnippet ?? "",
        link: item.link ?? "",
        pubDate: item.pubDate ?? "",
      }));

      res.json({
        success: true,
        data: news,
      });
    } catch (e) {
      console.error(e);

      res.status(500).json({
        success: false,
        error: "Failed to fetch RSS",
      });
    }
  }
);

