# Docling companion app

High-quality document-to-Markdown converter. Recommended parser backend for Libra OS's document ingestion pipeline when dealing with scanned PDFs, complex-layout PDFs, or DOCX with tables.

Image: [`ghcr.io/docling-project/docling-serve`](https://github.com/docling-project/docling) — Apache-2.0.

## Strengths

- Scanned PDFs via built-in OCR (EasyOCR / Tesseract).
- Multi-column / table-heavy PDFs.
- DOCX → Markdown with structured table extraction.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/docling/docker-compose.yaml up -d
```

API on `http://localhost:5001`.

## Wire to Libra OS

Add to the root `.env`:

```
DOCLING_URL=http://docling:5001
```

Then `docker compose up -d nova-os`. Libra OS auto-selects `RoutingParser{PDF: Docling, DOCX: Docling, HTML: Native}` when `DOCLING_URL` is set. Force Docling for everything via `NOVA_OS_PARSER=docling`.

## GPU acceleration

Docling can use a CUDA GPU for OCR. Uncomment the `deploy:` block in `docker-compose.yaml` and ensure the NVIDIA container runtime is installed on the host. Without GPU, OCR runs on CPU — still functional, slower on large scanned PDFs.

## Worker count

`DOCLING_WORKERS` (default `2`) controls parallel worker processes inside the container. Increase to `4–8` on hosts with many cores.
