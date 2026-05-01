"""
Minimal FastAPI wrapper around the flashrank Python library.

Exposes a single endpoint:
  POST /rerank
    Body: {"query": str, "documents": [str, ...], "top_k": int}
    Returns: {"results": [{"index": int, "score": float}, ...]}

The "index" field is the position of the passage in the input documents array.
"""

from fastapi import FastAPI
from pydantic import BaseModel
from flashrank import Ranker, RerankRequest

app = FastAPI(title="FlashRank sidecar", version="1.0.0")

# ms-marco-MiniLM-L-12-v2 is a well-tested cross-encoder (~34 MB, CPU-only).
# The older L-6-v2 was removed from the upstream HuggingFace repo in 2025;
# L-12-v2 is the nearest supported replacement — slightly larger but still
# small enough that CPU inference stays under 50ms per (query, passage) pair.
# Override via MODEL_NAME env var. Available models as of 2026-04:
#   ms-marco-MiniLM-L-12-v2, ms-marco-TinyBERT-L-2-v2,
#   ms-marco-MultiBERT-L-12, rank-T5-flan, Splade_PP_en_v1.
import os
_model_name = os.getenv("MODEL_NAME", "ms-marco-MiniLM-L-12-v2")
ranker = Ranker(model_name=_model_name)


class RerankReq(BaseModel):
    query: str
    documents: list[str]
    top_k: int = 10


@app.post("/rerank")
def rerank(req: RerankReq):
    passages = [{"id": i, "text": t} for i, t in enumerate(req.documents)]
    results = ranker.rerank(RerankRequest(query=req.query, passages=passages))
    top = results[: req.top_k]
    # flashrank returns np.float32 scores; FastAPI's default encoder can't
    # serialise them, so cast to native Python float before returning.
    return {"results": [{"index": int(r["id"]), "score": float(r["score"])} for r in top]}


@app.get("/health")
def health():
    return {"status": "ok", "model": _model_name}
