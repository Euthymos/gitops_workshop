<template>
  <main class="wrap">
    <h1>Todos</h1>

    <form class="row" @submit.prevent="addTodo">
      <input v-model="text" placeholder="Add a todo…" maxlength="200" />
      <button :disabled="!text.trim() || loading">Add</button>
    </form>

    <p v-if="error" class="error">{{ error }}</p>

    <ul class="list">
      <li v-for="t in todos" :key="t._id" class="item">
        <label class="todo">
          <input type="checkbox" :checked="t.done" @change="toggle(t)" />
          <span :class="{ done: t.done }">{{ t.text }}</span>
        </label>
        <button class="danger" @click="remove(t)" :disabled="loading">Delete</button>
      </li>
    </ul>
  </main>
</template>

<script setup>
import { onMounted, ref } from "vue";

const API_BASE = import.meta.env.VITE_API_BASE || "/api";

const todos = ref([]);
const text = ref("");
const error = ref("");
const loading = ref(false);

async function api(path, opts = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...opts
  });
  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);
  return data;
}

async function load() {
  error.value = "";
  todos.value = await api("/todos");
}

async function addTodo() {
  const v = text.value.trim();
  if (!v) return;
  loading.value = true;
  try {
    const created = await api("/todos", { method: "POST", body: JSON.stringify({ text: v }) });
    todos.value = [created, ...todos.value];
    text.value = "";
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

async function toggle(t) {
  loading.value = true;
  try {
    const updated = await api(`/todos/${t._id}`, {
      method: "PATCH",
      body: JSON.stringify({ done: !t.done })
    });
    todos.value = todos.value.map((x) => (x._id === t._id ? updated : x));
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

async function remove(t) {
  loading.value = true;
  try {
    await api(`/todos/${t._id}`, { method: "DELETE" });
    todos.value = todos.value.filter((x) => x._id !== t._id);
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  try {
    await load();
  } catch (e) {
    error.value = e.message;
  }
});
</script>

<style>
.wrap { max-width: 720px; margin: 40px auto; padding: 0 16px; font-family: system-ui, sans-serif; }
.row { display: flex; gap: 8px; }
input { flex: 1; padding: 10px 12px; font-size: 16px; }
button { padding: 10px 12px; cursor: pointer; }
.list { list-style: none; padding: 0; margin: 18px 0 0; display: grid; gap: 10px; }
.item { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 10px 12px; border: 1px solid #ddd; border-radius: 10px; }
.todo { display: flex; align-items: center; gap: 10px; }
.done { text-decoration: line-through; opacity: 0.6; }
.error { color: #b00020; margin-top: 10px; }
.danger { border: 1px solid #d33; }
</style>
