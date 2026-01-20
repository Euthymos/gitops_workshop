import express from "express";
import cors from "cors";
import mongoose from "mongoose";

const PORT = process.env.PORT || 8080;
const MONGO_URL = process.env.MONGO_URL || "mongodb://localhost:27017/todos";

const app = express();
app.use(cors());
app.use(express.json());

const todoSchema = new mongoose.Schema(
  {
    text: { type: String, required: true, trim: true, maxlength: 200 },
    done: { type: Boolean, default: false }
  },
  { timestamps: true }
);

const Todo = mongoose.model("Todo", todoSchema);

app.get("/health", (_req, res) => res.json({ ok: true }));

app.get("/todos", async (_req, res) => {
  const todos = await Todo.find().sort({ createdAt: -1 });
  res.json(todos);
});

app.post("/todos", async (req, res) => {
  const { text } = req.body || {};
  if (!text || !String(text).trim()) return res.status(400).json({ error: "text is required" });

  const todo = await Todo.create({ text: String(text).trim() });
  res.status(201).json(todo);
});

app.patch("/todos/:id", async (req, res) => {
  const { id } = req.params;
  const updates = {};
  if (req.body?.text !== undefined) updates.text = String(req.body.text).trim();
  if (req.body?.done !== undefined) updates.done = !!req.body.done;

  const todo = await Todo.findByIdAndUpdate(id, updates, { new: true, runValidators: true });
  if (!todo) return res.status(404).json({ error: "not found" });
  res.json(todo);
});

app.delete("/todos/:id", async (req, res) => {
  const { id } = req.params;
  const deleted = await Todo.findByIdAndDelete(id);
  if (!deleted) return res.status(404).json({ error: "not found" });
  res.status(204).send();
});

async function main() {
  const options = {
    user: process.env.MONGO_USER,
    pass: process.env.MONGO_PASSWORD,
  }
  await mongoose.connect(MONGO_URL, options);
  console.log("Connected to MongoDB");
  app.listen(PORT, () => console.log(`API listening on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
