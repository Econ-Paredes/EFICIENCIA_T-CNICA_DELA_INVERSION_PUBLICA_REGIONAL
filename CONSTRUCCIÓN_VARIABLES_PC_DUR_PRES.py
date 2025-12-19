# -*- coding: utf-8 -*-
"""
Construcción del panel de Registro Cierre 2015-2024
incluyendo:
 - Limpieza de categorías
 - Eliminación de MULTI-DEPARTAMENTO
 - Cálculo de DUR (promedio de duracion_meses por año y departamento)
 - Cálculo de NPROJ y PC (proporción)
 
Autor: MIGUEL.P
Fecha: 09/12/2025
"""

import os
import glob
import pandas as pd

# ======================================================
# 1. CARPETA DONDE ESTÁN LOS ARCHIVOS PROCESADOS
# ======================================================

BASE_DIR = r"D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\BASES DE DATOS"

# Patrón de búsqueda: todos los GOBIERNO_REGIONAL_*_PROCESADO_CON_DURACION.xlsx
patron = os.path.join(BASE_DIR, "GOBIERNO_REGIONAL_*_PROCESADO_CON_DURACION.xlsx")
archivos = glob.glob(patron)

print("Archivos encontrados:")
for a in archivos:
    print(" -", os.path.basename(a))

# ======================================================
# 2. LEER Y CONCATENAR TODAS LAS REGIONES
#    Conservando:
#    - Departamento
#    - año
#    - Registro Cierre
#    - duracion_meses
#    y eliminando MULTI-DEPARTAMENTO
# ======================================================

dfs = []

for ruta in archivos:
    df = pd.read_excel(ruta, engine="openpyxl")

    cols_necesarias = ["Departamento", "año", "Registro Cierre", "duracion_meses"]
    faltan = [c for c in cols_necesarias if c not in df.columns]
    if faltan:
        print(f"\n⚠️ En {os.path.basename(ruta)} faltan columnas: {faltan}")
        continue

    # Nos quedamos solo con las columnas necesarias
    df = df[cols_necesarias].copy()

    # Eliminar MULTI-DEPARTAMENTO a nivel de registro
    df["Departamento"] = df["Departamento"].astype(str)
    antes = df.shape[0]
    df = df[df["Departamento"].str.upper() != "MULTI-DEPARTAMENTO"]
    despues = df.shape[0]
    if antes - despues > 0:
        print(f"   - {os.path.basename(ruta)}: filas MULTI-DEPARTAMENTO eliminadas: {antes - despues}")

    dfs.append(df)

# Unimos todas las regiones
df_all = pd.concat(dfs, ignore_index=True)

print("\nValores únicos originales de 'Registro Cierre':")
print(df_all["Registro Cierre"].unique())

# ======================================================
# 3. TRATAR LAS CATEGORÍAS VACÍAS DE 'Registro Cierre'
#    - Quitar espacios
#    - Reemplazar vacío y NaN por 'Sin registro'
# ======================================================

df_all["Registro Cierre"] = (
    df_all["Registro Cierre"]
    .astype(str)
    .str.strip()
    .replace({"": "Sin registro"})
)

df_all["Registro Cierre"] = df_all["Registro Cierre"].fillna("Sin registro")

print("\nValores únicos de 'Registro Cierre' después de limpiar:")
print(df_all["Registro Cierre"].unique())

# ======================================================
# 4. FILTRAR AÑOS 2015–2024
# ======================================================

df_all = df_all[df_all["año"].between(2015, 2024)]

# ======================================================
# 5. CONTAR PROYECTOS POR Departamento, año y categoría
#    (para el panel de Registro Cierre)
# ======================================================

conteo = (
    df_all
    .groupby(["Departamento", "año", "Registro Cierre"])
    .size()
    .reset_index(name="n")
)

# Pivot a formato ancho: columnas = categorías de Registro Cierre
panel = (
    conteo
    .pivot_table(
        index=["Departamento", "año"],
        columns="Registro Cierre",   # incluye "Sin registro" y cualquier otra categoría
        values="n",
        fill_value=0
    )
    .reset_index()
)

panel.columns.name = None  # quitar nombre del nivel de columnas

# ======================================================
# 6. TOTAL GENERAL (suma de todas las categorías por Departamento-año)
# ======================================================

cols_categorias = [c for c in panel.columns if c not in ["Departamento", "año"]]
panel["Total general"] = panel[cols_categorias].sum(axis=1)

# Ordenar el panel
panel = panel.sort_values(["Departamento", "año"]).reset_index(drop=True)

# ======================================================
# 7. CALCULAR DUR = PROMEDIO ANUAL DE 'duracion_meses'
#    por Departamento y año (ignorando NaN)
# ======================================================

# Aseguramos que 'duracion_meses' sea numérico
df_all["duracion_meses"] = pd.to_numeric(df_all["duracion_meses"], errors="coerce")

dur_media = (
    df_all
    .groupby(["Departamento", "año"])["duracion_meses"]
    .mean()
    .reset_index()
    .rename(columns={"duracion_meses": "DUR"})
)

# Redondear DUR a número entero de meses
dur_media["DUR"] = dur_media["DUR"].round(0).astype("Int64")

# Unir DUR al panel
panel = panel.merge(dur_media, on=["Departamento", "año"], how="left")

# ======================================================
# 8. GUARDAR PANEL BÁSICO (ANTES DE NPROJ Y PC)
# ======================================================

salida = os.path.join(BASE_DIR, "PANEL_REGISTRO_CIERRE_2015_2024.xlsx")
panel.to_excel(salida, index=False, engine="openpyxl")

print("\n✅ Panel (con DUR) generado y guardado en:")
print(salida)
print("\nPrimeras filas del panel (previo a NPROJ y PC):")
print(panel.head())

# ======================================================
# 9. REABRIR EL PANEL Y CREAR NPROJ Y PC
#    PC = NPROJ / Total general (proporción, sin redondear)
# ======================================================

ruta_panel = salida  # mismo archivo

panel = pd.read_excel(ruta_panel, engine="openpyxl")

print("\nColumnas disponibles al reabrir el panel:")
print(panel.columns.tolist())

# Aseguramos que las categorías necesarias existan
categorias_nproj = [
    "SI/SNIP",
    "Sí, con liquidación",
    "Sí, en proceso de liquidación"
]

for col in categorias_nproj:
    if col not in panel.columns:
        print(f"⚠ La columna '{col}' no existe en el panel. Se creará con ceros.")
        panel[col] = 0

# NPROJ = suma de las 3 categorías
panel["NPROJ"] = (
    panel["SI/SNIP"]
    + panel["Sí, con liquidación"]
    + panel["Sí, en proceso de liquidación"]
)

# PC = proporción de proyectos con cierre (no redondeado)
if "Total general" not in panel.columns:
    raise ValueError("No se encontró la columna 'Total general' en el panel.")

panel["PC"] = None
mask_pc = panel["Total general"] > 0
panel.loc[mask_pc, "PC"] = (
    panel.loc[mask_pc, "NPROJ"] / panel.loc[mask_pc, "Total general"]
)

panel["PC"] = pd.to_numeric(panel["PC"], errors="coerce")

print("\n✅ Variables creadas:")
print(" - DUR (promedio anual de duracion_meses, redondeado a 2 decimales)")
print(" - NPROJ (conteo de proyectos con cierre)")
print(" - PC (proporción NPROJ/Total general, sin redondeo)")

# ======================================================
# 10. GUARDAR DEFINITIVAMENTE EL PANEL
# ======================================================

panel.to_excel(ruta_panel, index=False, engine="openpyxl")

print("\n✅ Archivo FINAL actualizado y guardado con el MISMO nombre:")
print(ruta_panel)

# ======================================================
# 11. VERIFICACIÓN RÁPIDA
# ======================================================

df_check = pd.read_excel(ruta_panel, engine="openpyxl")
print("\n✅ Vista rápida del DataFrame final:")
print(df_check.head())
