import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# Carga de datos
csv_path = os.path.join(os.path.dirname(__file__), "..", "datos", "viajes.csv")
df = pd.read_csv(csv_path)
total_filas = len(df)

# Parseo de fechas
pickup = pd.to_datetime(df['pickup_datetime'], format='%Y-%m-%d %H:%M:%S', errors='coerce')
dropoff_iso = pd.to_datetime(df['dropoff_datetime'], format='%Y-%m-%d %H:%M:%S', errors='coerce')
dropoff_dmy = pd.to_datetime(df['dropoff_datetime'], format='%d/%m/%Y %H:%M:%S', errors='coerce')
dropoff = dropoff_iso.fillna(dropoff_dmy)

# Duración y velocidad
df['duracion_min'] = (dropoff - pickup).dt.total_seconds() / 60.0
duracion_horas = df['duracion_min'] / 60.0
df['velocidad_mph'] = np.where(duracion_horas > 0, df['trip_distance'] / duracion_horas, np.nan)

# Métricas para IQR
def calcular_iqr(serie, solo_positivos=False):
    datos = serie[serie > 0] if solo_positivos else serie.dropna()
    q1 = datos.quantile(0.25)
    q3 = datos.quantile(0.75)
    iqr = q3 - q1
    lim_inf = q1 - 1.5 * iqr
    lim_sup = q3 + 1.5 * iqr
    return q1, q3, iqr, lim_inf, lim_sup

d_q1, d_q3, d_iqr, _, d_sup = calcular_iqr(df['trip_distance'], solo_positivos=True)
outliers_dist = (df['trip_distance'] > d_sup).sum()
dist_astronomicas = (df['trip_distance'] > 3959).sum()

f_q1, f_q3, f_iqr, f_inf, f_sup = calcular_iqr(df['fare_amount'])
outliers_fare = ((df['fare_amount'] < f_inf) | (df['fare_amount'] > f_sup)).sum()
tarifas_negativas = (df['fare_amount'] <= 0).sum()

dur_q1, dur_q3, dur_iqr, _, dur_sup = calcular_iqr(df['duracion_min'], solo_positivos=True)
outliers_dur = ((df['duracion_min'] <= 0) | (df['duracion_min'] > dur_sup)).sum()
dur_cero_negativa = (df['duracion_min'] <= 0).sum()

v_q1, v_q3, v_iqr, _, v_sup = calcular_iqr(df['velocidad_mph'], solo_positivos=True)
outliers_vel = (df['velocidad_mph'] > v_sup).sum()
vel_gt_100 = (df['velocidad_mph'] > 100).sum()
vel_supersonica = (df['velocidad_mph'] > 767).sum()

# Resumen en consola
print("Distancia - Q1:", round(d_q1, 2), "Q3:", round(d_q3, 2), "IQR:", round(d_iqr, 2), "Lim sup:", round(d_sup, 2), "Outliers IQR:", outliers_dist, "Dist > Radio tierra:", dist_astronomicas)
print("Tarifa - Q1:", round(f_q1, 2), "Q3:", round(f_q3, 2), "IQR:", round(f_iqr, 2), "Rango IQR: [", round(f_inf, 2), ",", round(f_sup, 2), "] Outliers IQR:", outliers_fare, "Tarifa <= 0:", tarifas_negativas)
print("Duración - Q1:", round(dur_q1, 2), "Q3:", round(dur_q3, 2), "IQR:", round(dur_iqr, 2), "Lim sup:", round(dur_sup, 2), "Outliers IQR:", outliers_dur, "Duración <= 0:", dur_cero_negativa)
print("Velocidad - Q1:", round(v_q1, 2), "Q3:", round(v_q3, 2), "IQR:", round(v_iqr, 2), "Lim sup:", round(v_sup, 2), "Outliers IQR:", outliers_vel, "Vel > 100 mph:", vel_gt_100)

# Generación de boxplots
output_dir = os.path.join(os.path.dirname(__file__), "output")
os.makedirs(output_dir, exist_ok=True)

def plot_horizontal_boxplot(datos, titulo, xlabel, filename, scale_type='linear', linthresh=25):
    datos_limpios = datos.dropna()
    fig, ax = plt.subplots(figsize=(9, 3.2))

    ax.boxplot(
        datos_limpios,
        orientation='horizontal',
        patch_artist=True,
        widths=0.45,
        boxprops=dict(facecolor='#D9E2EC', color='#102A43', linewidth=1.5),
        medianprops=dict(color='#BA2525', linewidth=2),
        whiskerprops=dict(color='#102A43', linewidth=1.2),
        capprops=dict(color='#102A43', linewidth=1.2),
        flierprops=dict(marker='o', markersize=3.5, alpha=0.35, markerfacecolor='#D64545', markeredgecolor='none')
    )

    ax.set_title(titulo, fontsize=12, fontweight='bold', pad=12, color='#102A43')
    ax.set_xlabel(xlabel, fontsize=10, color='#102A43')
    ax.set_yticks([])
    ax.grid(axis='x', linestyle='--', alpha=0.6)

    if scale_type == 'log':
        ax.set_xscale('log')
    elif scale_type == 'symlog':
        ax.set_xscale('symlog', linthresh=linthresh)
        ax.xaxis.set_major_formatter(ticker.ScalarFormatter())

    plt.tight_layout()
    ruta = os.path.join(output_dir, filename)
    plt.savefig(ruta, dpi=300)
    plt.close()

plot_horizontal_boxplot(
    df[df['trip_distance'] > 0]['trip_distance'],
    "Distribución de Distancia de Viaje",
    "Distancia en millas (escala logarítmica)",
    "boxplot_distancia.png",
    scale_type='log'
)

plot_horizontal_boxplot(
    df['fare_amount'],
    "Distribución de Tarifa Base",
    "Tarifa en dólares (escala simétrica)",
    "boxplot_tarifa.png",
    scale_type='symlog',
    linthresh=25
)

plot_horizontal_boxplot(
    df[df['duracion_min'] > 0]['duracion_min'],
    "Distribución de Duración de Viaje",
    "Duración en minutos (escala logarítmica)",
    "boxplot_duracion.png",
    scale_type='log'
)

plot_horizontal_boxplot(
    df[df['velocidad_mph'] > 0]['velocidad_mph'],
    "Distribución de Velocidad Estimada",
    "Velocidad en mph (escala logarítmica)",
    "boxplot_velocidad.png",
    scale_type='log'
)
