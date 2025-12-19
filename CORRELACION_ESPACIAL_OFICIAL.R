############################################################
# ANALISIS ESPACIAL ET (PERÚ, REGIONES) – SCRIPT INTEGRADO
# - Moran I (Global) con 3 matrices de pesos: Queen / kNN / IDW
# - Moran Scatterplot con etiquetas (Queen)
# - LISA (Moran Local) + Mapas: Queen / kNN / IDW
# - Hotspots / Coldspots: Getis–Ord Gi* (Queen)
# - Una sola tabla resumen (4 “bloques”): Moran + LISA Queen + LISA kNN + LISA IDW
#
# Carpeta:
# D:/MIGUEL PAREDES  M.2/Desktop/MIGUEL PAREDES/MAESTRIA TITULACIÓN/ESTIMACIONES/ESTIMACIÓN_SFA
############################################################

rm(list = ls())

wd <- "D:/MIGUEL PAREDES  M.2/Desktop/MIGUEL PAREDES/MAESTRIA TITULACIÓN/ESTIMACIONES/ESTIMACIÓN_SFA"
setwd(wd)

#-----------------------------------------------------------
# 0) PAQUETES
#-----------------------------------------------------------
packs <- c("sf","dplyr","readxl","stringi","stringr","spdep","tmap","writexl")
to_install <- packs[!packs %in% installed.packages()[,"Package"]]
if(length(to_install) > 0) install.packages(to_install)

library(sf)
library(dplyr)
library(readxl)
library(stringi)
library(stringr)
library(spdep)
library(tmap)
library(writexl)

#-----------------------------------------------------------
# 1) FUNCIONES AUXILIARES
#-----------------------------------------------------------
norm_region <- function(x){
  x %>%
    as.character() %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    toupper() %>%
    str_replace_all("\\s+", " ") %>%
    trimws()
}

# Crea clusters LISA (usa posiciones -> compatible en todas las versiones)
make_lisa_clusters <- function(sf_obj, xvar, listw_obj, alpha = 0.05, prefix = "q"){
  x <- sf_obj[[xvar]]
  lisa <- localmoran(x, listw_obj, zero.policy = TRUE)
  
  # z clásico para cuadrantes (Moran scatterplot / LISA)
  z  <- as.numeric(scale(x))
  wz <- lag.listw(listw_obj, z, zero.policy = TRUE)
  
  out <- sf_obj
  out[[paste0("Ii_", prefix)]]      <- lisa[,1]
  out[[paste0("Z_Ii_", prefix)]]    <- lisa[,4]
  out[[paste0("p_value_", prefix)]] <- lisa[,5]
  out[[paste0("z_", prefix)]]       <- z
  out[[paste0("wz_", prefix)]]      <- wz
  
  pv <- out[[paste0("p_value_", prefix)]]
  zz <- out[[paste0("z_", prefix)]]
  ww <- out[[paste0("wz_", prefix)]]
  
  out[[paste0("cluster_LISA_", prefix)]] <- dplyr::case_when(
    pv < alpha & zz >= 0 & ww >= 0 ~ "Alta–Alta (HH)",
    pv < alpha & zz <  0 & ww <  0 ~ "Baja–Baja (LL)",
    pv < alpha & zz >= 0 & ww <  0 ~ "Alta–Baja (HL)",
    pv < alpha & zz <  0 & ww >= 0 ~ "Baja–Alta (LH)",
    TRUE                           ~ "No significativo"
  )
  out
}

# Resumen de clusters (conteos)
cluster_counts <- function(sf_obj, cluster_col){
  tab <- table(sf_obj[[cluster_col]])
  getn <- function(nm) ifelse(nm %in% names(tab), as.integer(tab[[nm]]), 0L)
  data.frame(
    n_sig = sum(sf_obj[[cluster_col]] != "No significativo"),
    n_HH  = getn("Alta–Alta (HH)"),
    n_LL  = getn("Baja–Baja (LL)"),
    n_HL  = getn("Alta–Baja (HL)"),
    n_LH  = getn("Baja–Alta (LH)")
  )
}

#-----------------------------------------------------------
# 2) CARGAR MAPA (GeoJSON) + PREPARAR LLAVE
#-----------------------------------------------------------
geo_file <- "peru_departamental_simple.json"
geo_region_field <- "NOMBDEP"  # ajusta si tu geojson usa otro campo

peru_dep <- st_read(geo_file, quiet = TRUE)

# Si no trae CRS (tu caso), asignamos WGS84 para evitar advertencias al exportar
if (is.na(st_crs(peru_dep))) st_crs(peru_dep) <- 4326

peru_dep <- peru_dep %>%
  mutate(
    Region = norm_region(.data[[geo_region_field]]),
    Region = case_when(
      Region %in% c("CUSCO","CUZCO") ~ "CUSCO",
      Region %in% c("LA LIBERTAD","LIBERTAD") ~ "LA LIBERTAD",
      Region %in% c("LIMA","LIMA METROPOLITANA") ~ "LIMA",
      TRUE ~ Region
    )
  )

#-----------------------------------------------------------
# 3) CARGAR BASE ET (Excel) + UNIR
#-----------------------------------------------------------
base_sfa <- read_excel("BASE_SFA_FINAL.xlsx")

if(!("TE_IRIPR" %in% names(base_sfa))) stop("No existe TE_IRIPR en BASE_SFA_FINAL.xlsx")
if(!("Region" %in% names(base_sfa)))    stop("No existe columna Region en BASE_SFA_FINAL.xlsx")

base_sfa <- base_sfa %>%
  mutate(
    Region = norm_region(Region),
    ET = as.numeric(TE_IRIPR)
  ) %>%
  mutate(
    Region = case_when(
      Region %in% c("CUSCO","CUZCO") ~ "CUSCO",
      Region %in% c("LA LIBERTAD","LIBERTAD") ~ "LA LIBERTAD",
      Region %in% c("LIMA","LIMA METROPOLITANA") ~ "LIMA",
      TRUE ~ Region
    )
  )

# ET por región (promedio si hay panel en el excel)
ET_reg <- base_sfa %>%
  group_by(Region) %>%
  summarise(ET = mean(ET, na.rm = TRUE), .groups = "drop")

map_et <- peru_dep %>%
  left_join(ET_reg, by = "Region") %>%
  filter(!is.na(ET))

#-----------------------------------------------------------
# 4) MATRICES DE PESOS: QUEEN / kNN / IDW
#-----------------------------------------------------------

# 4.1 Queen (contigüidad)
nb_queen <- poly2nb(map_et, queen = TRUE)
lw_queen <- nb2listw(nb_queen, style = "W", zero.policy = TRUE)

# 4.2 k-Nearest Neighbors (k = 4) – para heterogeneidad de tamaño
coords <- st_coordinates(st_centroid(map_et))
knn4   <- knearneigh(coords, k = 4)
nb_knn <- knn2nb(knn4)
lw_knn <- nb2listw(nb_knn, style = "W", zero.policy = TRUE)

# 4.3 Distancia inversa (IDW)
dist_mat <- as.matrix(dist(coords))
inv_dist <- 1 / dist_mat
diag(inv_dist) <- 0
inv_dist <- inv_dist / rowSums(inv_dist)
lw_idw <- mat2listw(inv_dist, style = "W", zero.policy = TRUE)

#-----------------------------------------------------------
# 5) MORAN I (GLOBAL) – 3 pesos + “bloque Moran”
#-----------------------------------------------------------
m_q <- moran.test(map_et$ET, lw_queen, zero.policy = TRUE)
m_k <- moran.test(map_et$ET, lw_knn,   zero.policy = TRUE)
m_i <- moran.test(map_et$ET, lw_idw,   zero.policy = TRUE)

moran_table <- data.frame(
  Metodo = c("Moran I (Queen)", "Moran I (kNN k=4)", "Moran I (IDW)"),
  I = c(unname(m_q$estimate[["Moran I statistic"]]),
        unname(m_k$estimate[["Moran I statistic"]]),
        unname(m_i$estimate[["Moran I statistic"]])),
  p_value = c(m_q$p.value, m_k$p.value, m_i$p.value)
)

#-----------------------------------------------------------
# 6) MORAN SCATTERPLOT (Queen) – con etiquetas + exportar
#-----------------------------------------------------------
z_q  <- as.numeric(scale(map_et$ET))
wz_q <- lag.listw(lw_queen, z_q, zero.policy = TRUE)

png("SCATTER_MORAN_ET_QUEEN.png", width = 1800, height = 1200, res = 200)
plot(z_q, wz_q,
     xlab = "ET estandarizada (z)",
     ylab = "Rezago espacial (Wz)",
     main = "Moran Scatterplot – Eficiencia Técnica (ET) [Pesos Queen]",
     pch = 20)
abline(h = 0, v = 0, lty = 2)
abline(lm(wz_q ~ z_q), col = "blue", lwd = 2)
text(z_q, wz_q, labels = map_et$Region, cex = 0.55, pos = 3)
mtext(paste0("Moran I = ",
             round(unname(m_q$estimate[["Moran I statistic"]]), 4),
             " | p-valor = ",
             signif(m_q$p.value, 4)),
      side = 1, line = 3, cex = 0.85)
dev.off()

#-----------------------------------------------------------
# 7) LISA – Queen / kNN / IDW (α = 0.05) + Mapas
#-----------------------------------------------------------
alpha <- 0.05

map_q <- make_lisa_clusters(map_et, "ET", lw_queen, alpha = alpha, prefix = "queen")
map_k <- make_lisa_clusters(map_et, "ET", lw_knn,   alpha = alpha, prefix = "knn")
map_i <- make_lisa_clusters(map_et, "ET", lw_idw,   alpha = alpha, prefix = "idw")

# Conteos para tabla resumen (LISA)
cc_q <- cluster_counts(map_q, "cluster_LISA_queen"); cc_q$Metodo <- "LISA (Queen)"
cc_k <- cluster_counts(map_k, "cluster_LISA_knn");   cc_k$Metodo <- "LISA (kNN k=4)"
cc_i <- cluster_counts(map_i, "cluster_LISA_idw");   cc_i$Metodo <- "LISA (IDW)"

#-----------------------------------------------------------
# 8) HOTSPOTS / COLDSPOTS – Getis–Ord Gi* (Queen) + Mapa
#-----------------------------------------------------------
map_et$Gi_star <- as.numeric(localG(map_et$ET, lw_queen, zero.policy = TRUE))

#-----------------------------------------------------------
# 9) MAPAS (tmap) – exportar todos
#-----------------------------------------------------------
tmap_mode("plot")

# 9.1 LISA Queen
tm_LISA_queen <- tm_shape(map_q) +
  tm_polygons("cluster_LISA_queen", title = "LISA (Queen)", colorNA = "white") +
  tm_borders() +
  tm_layout(main.title = "Clusters espaciales de ET – LISA Queen",
            legend.outside = TRUE)

# 9.2 LISA kNN
tm_LISA_knn <- tm_shape(map_k) +
  tm_polygons("cluster_LISA_knn", title = "LISA (kNN, k=4)", colorNA = "white") +
  tm_borders() +
  tm_layout(main.title = "Clusters espaciales de ET – LISA k-Nearest Neighbors",
            legend.outside = TRUE)

# 9.3 LISA IDW
tm_LISA_idw <- tm_shape(map_i) +
  tm_polygons("cluster_LISA_idw", title = "LISA (IDW)", colorNA = "white") +
  tm_borders() +
  tm_layout(main.title = "Clusters espaciales de ET – LISA Distancia Inversa",
            legend.outside = TRUE)

# 9.4 Hotspots / Coldspots (Gi*)
tm_GI <- tm_shape(map_et) +
  tm_polygons("Gi_star", title = "Getis–Ord Gi*", palette = "-RdBu", colorNA = "white") +
  tm_borders() +
  tm_layout(main.title = "Hotspots / Coldspots de ET – Getis–Ord Gi* (Queen)",
            legend.outside = TRUE)

# Guardar mapas
tmap_save(tm_LISA_queen, "MAPA_LISA_ET_QUEEN.png", width = 1800, height = 1200)
tmap_save(tm_LISA_knn,   "MAPA_LISA_ET_kNN.png",   width = 1800, height = 1200)
tmap_save(tm_LISA_idw,   "MAPA_LISA_ET_IDW.png",   width = 1800, height = 1200)
tmap_save(tm_GI,         "MAPA_GI_ET.png",         width = 1800, height = 1200)

# (Opcional) comparación lado a lado
tm_comp <- tmap_arrange(tm_LISA_queen, tm_LISA_knn, tm_LISA_idw, tm_GI, ncol = 2)
tmap_save(tm_comp, "MAPA_COMPUESTO_LISA_GI.png", width = 2400, height = 1800)

#-----------------------------------------------------------
# 10) TABLA ÚNICA RESUMEN (4 BLOQUES) + EXPORTAR
#-----------------------------------------------------------
# “Bloque Moran” (una fila agregada) usando Queen como base del texto principal
moran_block <- data.frame(
  Metodo = "Moran I (Global, Queen) – principal",
  I      = unname(m_q$estimate[["Moran I statistic"]]),
  p_value = m_q$p.value,
  n_sig = NA, n_HH = NA, n_LL = NA, n_HL = NA, n_LH = NA
)

# “Bloques LISA”
lisa_block <- bind_rows(cc_q, cc_k, cc_i) %>%
  mutate(I = NA_real_, p_value = NA_real_) %>%
  select(Metodo, I, p_value, n_sig, n_HH, n_LL, n_HL, n_LH)

tabla_resumen <- bind_rows(
  moran_block,
  lisa_block
)

# Exportar tabla resumen
write.csv(tabla_resumen, "TABLA_RESUMEN_MORAN_LISA.csv", row.names = FALSE)
write_xlsx(tabla_resumen, "TABLA_RESUMEN_MORAN_LISA.xlsx")

# Exportar tabla Moran completa (3 pesos) por si lo quieres en anexos
write.csv(moran_table, "TABLA_MORAN_TRES_PESOS.csv", row.names = FALSE)

#-----------------------------------------------------------
# 11) EXPORTAR TABLAS DETALLADAS (OPCIONAL) – regiones sig
#-----------------------------------------------------------
sig_queen <- map_q %>% st_drop_geometry() %>%
  filter(cluster_LISA_queen != "No significativo") %>%
  select(Region, ET, Ii_queen, Z_Ii_queen, p_value_queen, cluster_LISA_queen) %>%
  arrange(p_value_queen)

sig_knn <- map_k %>% st_drop_geometry() %>%
  filter(cluster_LISA_knn != "No significativo") %>%
  select(Region, ET, Ii_knn, Z_Ii_knn, p_value_knn, cluster_LISA_knn) %>%
  arrange(p_value_knn)

sig_idw <- map_i %>% st_drop_geometry() %>%
  filter(cluster_LISA_idw != "No significativo") %>%
  select(Region, ET, Ii_idw, Z_Ii_idw, p_value_idw, cluster_LISA_idw) %>%
  arrange(p_value_idw)

write_xlsx(
  list(
    "Moran_3_pesos" = moran_table,
    "Resumen_Moran_LISA" = tabla_resumen,
    "LISA_sig_Queen" = sig_queen,
    "LISA_sig_kNN" = sig_knn,
    "LISA_sig_IDW" = sig_idw,
    "Gi_star" = (map_et %>% st_drop_geometry() %>% select(Region, ET, Gi_star))
  ),
  "TABLAS_RESULTADOS_ESPACIALES_ET.xlsx"
)

cat("\nLISTO ✅\n",
    "Exportados:\n",
    "- SCATTER_MORAN_ET_QUEEN.png\n",
    "- MAPA_LISA_ET_QUEEN.png\n",
    "- MAPA_LISA_ET_kNN.png\n",
    "- MAPA_LISA_ET_IDW.png\n",
    "- MAPA_GI_ET.png\n",
    "- MAPA_COMPUESTO_LISA_GI.png\n",
    "- TABLA_RESUMEN_MORAN_LISA.csv / .xlsx\n",
    "- TABLA_MORAN_TRES_PESOS.csv\n",
    "- TABLAS_RESULTADOS_ESPACIALES_ET.xlsx\n")
