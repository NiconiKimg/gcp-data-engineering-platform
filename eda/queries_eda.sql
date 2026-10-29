-- Outliers de distancia por IQR
WITH limites AS (
  SELECT
    APPROX_QUANTILES(trip_distance, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(trip_distance, 100)[OFFSET(75)] AS q3
  FROM `tp_raw.viajes`
  WHERE trip_distance > 0
),
umbral AS (
  SELECT q3 + 1.5 * (q3 - q1) AS limite_superior
  FROM limites
)
SELECT
  v.vendor_id,
  v.pickup_datetime,
  v.dropoff_datetime,
  v.pickup_location_id,
  v.dropoff_location_id,
  v.trip_distance
FROM `tp_raw.viajes` v
CROSS JOIN umbral u
WHERE v.trip_distance > u.limite_superior
ORDER BY v.trip_distance DESC;

-- Outliers de tarifa por IQR
WITH limites AS (
  SELECT
    APPROX_QUANTILES(fare_amount, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(fare_amount, 100)[OFFSET(75)] AS q3
  FROM `tp_raw.viajes`
),
umbrales AS (
  SELECT
    q1 - 1.5 * (q3 - q1) AS limite_inferior,
    q3 + 1.5 * (q3 - q1) AS limite_superior
  FROM limites
)
SELECT
  v.vendor_id,
  v.pickup_datetime,
  v.dropoff_datetime,
  v.payment_type,
  v.fare_amount
FROM `tp_raw.viajes` v
CROSS JOIN umbrales u
WHERE v.fare_amount < u.limite_inferior OR v.fare_amount > u.limite_superior
ORDER BY v.fare_amount ASC;

-- Outliers de duración por IQR
WITH viajes_duracion AS (
  SELECT
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    TIMESTAMP_DIFF(
      COALESCE(
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', dropoff_datetime),
        SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', dropoff_datetime)
      ),
      pickup_datetime,
      SECOND
    ) / 60.0 AS duracion_min
  FROM `tp_raw.viajes`
),
limites AS (
  SELECT
    APPROX_QUANTILES(duracion_min, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(duracion_min, 100)[OFFSET(75)] AS q3
  FROM viajes_duracion
  WHERE duracion_min > 0
),
umbrales AS (
  SELECT
    q3 + 1.5 * (q3 - q1) AS limite_superior
  FROM limites
)
SELECT
  v.vendor_id,
  v.pickup_datetime,
  v.dropoff_datetime,
  ROUND(v.duracion_min, 2) AS duracion_min
FROM viajes_duracion v
CROSS JOIN umbrales u
WHERE v.duracion_min <= 0 OR v.duracion_min > u.limite_superior
ORDER BY v.duracion_min DESC;

-- Outliers de velocidad por IQR
WITH viajes_velocidad AS (
  SELECT
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    trip_distance,
    TIMESTAMP_DIFF(
      COALESCE(
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', dropoff_datetime),
        SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', dropoff_datetime)
      ),
      pickup_datetime,
      SECOND
    ) / 3600.0 AS duracion_horas
  FROM `tp_raw.viajes`
),
calculos AS (
  SELECT
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    trip_distance,
    duracion_horas,
    SAFE_DIVIDE(trip_distance, duracion_horas) AS velocidad_mph
  FROM viajes_velocidad
  WHERE duracion_horas > 0
),
limites AS (
  SELECT
    APPROX_QUANTILES(velocidad_mph, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(velocidad_mph, 100)[OFFSET(75)] AS q3
  FROM calculos
  WHERE velocidad_mph > 0
),
umbrales AS (
  SELECT
    q3 + 1.5 * (q3 - q1) AS limite_superior
  FROM limites
)
SELECT
  c.vendor_id,
  c.pickup_datetime,
  c.dropoff_datetime,
  c.trip_distance,
  ROUND(c.duracion_horas * 60, 2) AS duracion_min,
  ROUND(c.velocidad_mph, 2) AS velocidad_mph
FROM calculos c
CROSS JOIN umbrales u
WHERE c.velocidad_mph > u.limite_superior
ORDER BY c.velocidad_mph DESC;

-- Resumen consolidado de outliers
WITH base AS (
  SELECT
    trip_distance,
    fare_amount,
    TIMESTAMP_DIFF(
      COALESCE(
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', dropoff_datetime),
        SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', dropoff_datetime)
      ),
      pickup_datetime,
      SECOND
    ) / 60.0 AS duracion_min,
    SAFE_DIVIDE(
      trip_distance,
      (TIMESTAMP_DIFF(
        COALESCE(
          SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', dropoff_datetime),
          SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', dropoff_datetime)
        ),
        pickup_datetime,
        SECOND
      ) / 3600.0)
    ) AS velocidad_mph
  FROM `tp_raw.viajes`
),
cuantiles AS (
  SELECT
    APPROX_QUANTILES(IF(trip_distance > 0, trip_distance, NULL), 100)[OFFSET(75)] + 1.5 * (
      APPROX_QUANTILES(IF(trip_distance > 0, trip_distance, NULL), 100)[OFFSET(75)] -
      APPROX_QUANTILES(IF(trip_distance > 0, trip_distance, NULL), 100)[OFFSET(25)]
    ) AS lim_dist_iqr,
    APPROX_QUANTILES(fare_amount, 100)[OFFSET(25)] - 1.5 * (
      APPROX_QUANTILES(fare_amount, 100)[OFFSET(75)] -
      APPROX_QUANTILES(fare_amount, 100)[OFFSET(25)]
    ) AS lim_fare_inf_iqr,
    APPROX_QUANTILES(fare_amount, 100)[OFFSET(75)] + 1.5 * (
      APPROX_QUANTILES(fare_amount, 100)[OFFSET(75)] -
      APPROX_QUANTILES(fare_amount, 100)[OFFSET(25)]
    ) AS lim_fare_sup_iqr,
    APPROX_QUANTILES(IF(duracion_min > 0, duracion_min, NULL), 100)[OFFSET(75)] + 1.5 * (
      APPROX_QUANTILES(IF(duracion_min > 0, duracion_min, NULL), 100)[OFFSET(75)] -
      APPROX_QUANTILES(IF(duracion_min > 0, duracion_min, NULL), 100)[OFFSET(25)]
    ) AS lim_dur_iqr,
    APPROX_QUANTILES(IF(velocidad_mph > 0, velocidad_mph, NULL), 100)[OFFSET(75)] + 1.5 * (
      APPROX_QUANTILES(IF(velocidad_mph > 0, velocidad_mph, NULL), 100)[OFFSET(75)] -
      APPROX_QUANTILES(IF(velocidad_mph > 0, velocidad_mph, NULL), 100)[OFFSET(25)]
    ) AS lim_vel_iqr
  FROM base
)
SELECT
  COUNT(*) AS total_registros,
  COUNTIF(trip_distance > (SELECT lim_dist_iqr FROM cuantiles)) AS outliers_distancia_iqr,
  COUNTIF(fare_amount < (SELECT lim_fare_inf_iqr FROM cuantiles) OR fare_amount > (SELECT lim_fare_sup_iqr FROM cuantiles)) AS outliers_tarifa_iqr,
  COUNTIF(duracion_min <= 0 OR duracion_min > (SELECT lim_dur_iqr FROM cuantiles)) AS outliers_duracion_iqr,
  COUNTIF(velocidad_mph > (SELECT lim_vel_iqr FROM cuantiles)) AS outliers_velocidad_iqr,
  COUNTIF(trip_distance > 3959) AS distancias_mayores_radio_tierra,
  COUNTIF(velocidad_mph > 100) AS viajes_velocidad_gt_100mph,
  COUNTIF(duracion_min <= 0) AS viajes_duracion_cero_o_negativa,
  COUNTIF(fare_amount <= 0) AS tarifas_cero_o_negativas
FROM base;
