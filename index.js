const express = require("express");
const { BigQuery } = require("@google-cloud/bigquery");
const { Storage } = require("@google-cloud/storage");

const bigquery = new BigQuery();
const storage = new Storage();

const app = express();
const port = 8080;

app.use(express.json());

app.post("/cloudEvent", async (req, res) => {
  const timestamp = new Date().toISOString();
  const event = req.body;

  const file = storage.bucket("dora-github-push-event").file(event.name);
  const [content] = await file.download();

  const jsonData = JSON.parse(content.toString());

  const payload = {
    ingestion_time: timestamp,
    data: JSON.stringify(jsonData),
  };

  try {
    await bigquery.dataset(`dora`).table(`batch_events`).insert([payload]);

    console.log("PAYLOAD WAS INGESTED SUCCESSFULLY");
    res.status(200).send("Payload ingested successfully");
  } catch (err) {
    console.error("SOMETHING WENT WRONG:", err);
    res.status(500).send("Internal Server Error");
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
