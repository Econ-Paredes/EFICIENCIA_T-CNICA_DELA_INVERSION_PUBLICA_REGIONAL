# -*- coding: utf-8 -*-
"""
Created on Tue Dec  9 18:41:48 2025

@author: MIGUEL.P
"""

import os
import glob
import pandas as pd

# ======================================================
# 1. CARPETA DONDE ESTÁN LOS ARCHIVOS PROCESADOS
# ======================================================

BASE_DIR = r"D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\BASES DE DATOS"

patron = os.path.join(BASE_DIR, "GOBIERNO_REGIONAL_*_PROCESADO_CON_DURACION.xlsx")
archivos = glob.glob(patron)

print("Archivos encontrados:")
for a in archivos:
    print(" -", os.path.basename(a))

# ======================================================
# 2. LEER Y CONCATENAR TODAS LAS REGIONES
# ======================================================

dfs = []

for ruta in archivos:
    df = pd.read_excel(ruta, engine="openpyxl")

    cols_necesarias = ["Departamento", "año", "Registro Cierre"]
    faltan = [c for c in cols_necesarias if c not in df.columns]
    if faltan:
        print(f"\n⚠️ En {os.path.basename(ruta)} faltan columnas: {faltan}")
        continue

    df = df[cols_necesarias].copy()
    dfs.append(df)

df_all = pd.concat(dfs, ignore_index=True)

print("\nValores únicos originales de 'Registro Cierre':")
print(df_all["Registro Cierre"].unique())

# ======================================================
# 3. TRATAR LAS CATEGORÍAS VACÍAS COMO UNA COLUMNA MÁS
#    (para no perder ningún dato)
# ======================================================

df_all["Registro Cierre"] = (
    df_all["Registro Cierre"]
    .astype(str)
    .str.strip()
    .replace({"": "Sin registro"})
)

# si vinieran NaN, por si acaso:
df_all["Registro Cierre"] = df_all["Registro Cierre"].fillna("Sin registro")

print("\nValores únicos de 'Registro Cierre' después de limpiar:")
print(df_all["Registro Cierre"].unique())

# ======================================================
# 4. FILTRAR AÑOS 2015–2024
# ======================================================

df_all = df_all[df_all["año"].between(2015, 2024)]

# ======================================================
# 5. CONTAR POR Departamento, año y categoría
# ======================================================

conteo = (
    df_all
    .groupby(["Departamento", "año", "Registro Cierre"])
    .size()
    .reset_index(name="n")
)

panel = (
    conteo
    .pivot_table(
        index=["Departamento", "año"],
        columns="Registro Cierre",   # incluye "Sin registro"
        values="n",
        fill_value=0
    )
    .reset_index()
)

panel.columns.name = None

# ======================================================
# 6. TOTAL GENERAL
# ======================================================

cols_categorias = [c for c in panel.columns if c not in ["Departamento", "año"]]
panel["Total general"] = panel[cols_categorias].sum(axis=1)

panel = panel.sort_values(["Departamento", "año"]).reset_index(drop=True)

# ======================================================
# 7. GUARDAR
# ======================================================

salida = os.path.join(BASE_DIR, "PANEL_REGISTRO_CIERRE_2015_2024.xlsx")
panel.to_excel(salida, index=False, engine="openpyxl")

print("\n✅ Panel generado y guardado en:")
print(salida)
print("\nPrimeras filas del panel:")
print(panel.head())
