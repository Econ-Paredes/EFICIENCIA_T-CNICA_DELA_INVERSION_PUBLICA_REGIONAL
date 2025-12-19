# -*- coding: utf-8 -*-
"""
Convierte SUPERFICIE REGIONAL a PANEL LARGO 2015–2024
Replicando el mismo valor de superficie para cada año.
Estructura final:
REGION | AÑO | SUPERFICIE
"""

import os
import pandas as pd

# ======================================================
# 1. CARPETA DE TRABAJO
# ======================================================

WORK_DIR = r"D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\BASES DE DATOS"
os.chdir(WORK_DIR)

print("📂 Carpeta de trabajo:")
print(os.getcwd())

# ======================================================
# 2. LEER ARCHIVO ORIGINAL
# ======================================================

archivo_entrada = "SUPERFICIE REGIONAL.xlsx"
archivo_salida  = "SUPERFICIE_PANEL_LARGO_2015_2024.xlsx"

df = pd.read_excel(archivo_entrada, engine="openpyxl")

print("\nColumnas originales detectadas:")
print(df.columns.tolist())

# ======================================================
# 3. NORMALIZAR NOMBRE DE COLUMNAS
# ======================================================

df = df.rename(columns={
    df.columns[0]: "REGION",
    df.columns[1]: "SUPERFICIE"
})

# asegurar tipo numérico
df["SUPERFICIE"] = pd.to_numeric(df["SUPERFICIE"], errors="coerce")

# ======================================================
# 4. CREAR PANEL LARGO 2015–2024 (REPLICADO)
# ======================================================

anios = list(range(2015, 2025))

panel_largo = (
    df.assign(key=1)
      .merge(pd.DataFrame({"AÑO": anios, "key": 1}), on="key")
      .drop("key", axis=1)
)

# ordenar
panel_largo = panel_largo.sort_values(["REGION", "AÑO"]).reset_index(drop=True)

print("\n✅ Vista previa del panel largo:")
print(panel_largo.head(10))

# ======================================================
# 5. GUARDAR RESULTADO
# ======================================================

panel_largo.to_excel(archivo_salida, index=False, engine="openpyxl")

print("\n✅ PANEL LARGO DE SUPERFICIE (2015–2024) generado en:")
print(archivo_salida)