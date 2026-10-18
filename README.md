# GCP Data Engineering Platform

Proyecto desarrollado en el marco del curso **Introducción a la Ingeniería de Datos en Google Cloud**, dictado por la **UTN Facultad Regional Rosario** y **TheLab Technology**.

El proyecto se basa en las consignas y fuentes del repositorio original: [juanmantegazza/ingenieria-datos-gcp](https://github.com/juanmantegazza/ingenieria-datos-gcp).

## Estado actual · Parte 1 (Capa Raw)

Implementación de la ingesta bruta en BigQuery:
- Definición de esquemas declarativos en formato JSON para el control de tipos y nulabilidad.
- Creación del dataset `tp_raw` en la ubicación multi-región `US`.
- Carga y validación de las fuentes de datos: viajes de taxi en Nueva York (`viajes`) y registros meteorológicos horarios (`clima`).

## Estructura del repositorio

```text
gcp-data-engineering-platform/
├── schemas/
│   ├── viajes.json
│   └── clima.json
├── datos/
│   ├── viajes.csv
│   └── clima.csv
├── .gitignore
└── README.md
```
