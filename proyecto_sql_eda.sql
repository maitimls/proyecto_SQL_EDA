SELECT *
FROM DIM_CLIENTES dc 

SELECT *
FROM DIM_FECHA df 

SELECT *
FROM DIM_LOCALIZACION dl 

SELECT *
FROM DIM_PRODUCTO dp 

SELECT *
FROM FACT_VENTAS fv 

-- Para comprobar que todas las tablas se han cargado correctamente.

-- Para comenzar con los JOIN vamos a analizar si hay algún cliente que no haya hecho compras
-- Así nos da una visión real de si hay algún cliente inactivo.

SELECT 
	dc.PK_CLIENTE,
	dc.NOMBRE
FROM DIM_CLIENTES dc 
LEFT JOIN FACT_VENTAS fv 
	ON dc.PK_CLIENTE = fv.FK_CLIENTE 
-- Hasta aquí vemos qué compras ha hecho cada cliente.

SELECT 
	dc.PK_CLIENTE,
	dc.NOMBRE
FROM DIM_CLIENTES dc 
LEFT JOIN FACT_VENTAS fv 
	ON dc.PK_CLIENTE = fv.FK_CLIENTE 
WHERE fv.FK_CLIENTE IS NULL;

-- Nos devuelve una tabla vacía y por ello sabemos que no hay ningún cliente que no haya hecho compras.
-- En cambio, si lo hacemos a la inversa, podemos saber si hay algún producto que aún no se haya vendido.
-- La línea de Maitadona Beauty y Maitadona Natura es nueva y aún no se ha podido comprar por ello debería devolvernos esos 3 productos de esa línea.

SELECT
	dp.PK_PRODUCTO,
	dp.MARCA,
	dp.CATEGORIA 
FROM FACT_VENTAS fv 
RIGHT JOIN DIM_PRODUCTO dp 
	ON fv.FK_PRODUCTO = dp.PK_PRODUCTO 
WHERE fv.FK_PRODUCTO IS NULL;

-- Efectivamente nos devuelve los 3 productos nuevos de la Marca Maitadona.

-- Para comprobar ahora qué productos NO se han vendido en los diferentes territorios
SELECT 
	dp.PK_PRODUCTO,
	dp.MARCA,
	dp.SUBCATEGORIA AS PRODUCTO,
	dl.NOMBRE AS UBICACIÓN
FROM DIM_PRODUCTO dp
CROSS JOIN DIM_LOCALIZACION dl 
ORDER BY dp.PK_PRODUCTO ASC;
-- Vemos todos los productos y en qué localizaciones se han vendido.

-- Para identificar productos sin ventas por territorio/localización se realizan
-- todas las combinaciones posibles entre producto y localización con un 'CROSS JOIN'.
SELECT 
	dp.PK_PRODUCTO,
	dp.MARCA,
	dp.SUBCATEGORIA AS PRODUCTO,
	dl.NOMBRE AS UBICACIÓN
FROM DIM_PRODUCTO dp
CROSS JOIN DIM_LOCALIZACION dl 
LEFT JOIN FACT_VENTAS fv 
	ON fv.FK_PRODUCTO = dp.PK_PRODUCTO 
	AND fv.FK_LOCALIZACION = dl.PK_LOCALIZACION 
WHERE fv.FK_PRODUCTO IS NULL;

-- Podemos observar que todos los productos se han vendido en todos los territorios ya que solo
-- devuelve los nuevos que aun no han salido a la venta.


-- Incorporando una CTE simple, vamos ahora a ver qué productos son los más vendidos teniendo en cuenta la Cantidad.

WITH ventas_por_producto AS (
	SELECT
	    dp.PK_PRODUCTO AS ID, 
	    dp.SUBCATEGORIA AS PRODUCTO,
	    COUNT(fv.FK_PRODUCTO ) AS NUMERO_VENTAS -- Usamos COUNT para diferenciar unidades vendidas de ingresos.
	FROM DIM_PRODUCTO dp
	LEFT JOIN FACT_VENTAS fv
	    ON dp.PK_PRODUCTO = fv.FK_PRODUCTO
	GROUP BY dp.PK_PRODUCTO, dp.SUBCATEGORIA
)
SELECT *
FROM ventas_por_producto 
ORDER BY NUMERO_VENTAS DESC


-- Añadimos un CASE en un CTE encadenado para clasificar los productos y catalogar así los Best Seller.
WITH ventas_por_producto AS (
	SELECT
	    dp.PK_PRODUCTO AS ID, 
	    dp.SUBCATEGORIA AS PRODUCTO,
	    dp.MARCA ,
	    COUNT(fv.FK_PRODUCTO) AS NUMERO_VENTAS  -- Número de veces que se ha vendido el producto
	FROM DIM_PRODUCTO dp
	LEFT JOIN FACT_VENTAS fv
	  ON dp.PK_PRODUCTO = fv.FK_PRODUCTO
	GROUP BY dp.PK_PRODUCTO, dp.SUBCATEGORIA, dp.MARCA
	),
clasificacion_productos AS (
   SELECT 
	   	ID, 
	   	PRODUCTO, 
	   	MARCA,
	   	NUMERO_VENTAS,
		CASE
		  WHEN NUMERO_VENTAS >= 30 THEN 'Best Seller'
		  WHEN NUMERO_VENTAS >= 24 AND NUMERO_VENTAS < 30 THEN 'Ventas Standard'
		  ELSE 'Poco vendido'
		    END AS CATEGORIA_VENTAS
		FROM ventas_por_producto
	)
	SELECT *
	FROM clasificacion_productos
	ORDER BY NUMERO_VENTAS DESC;

-- Podemos destacar 4 productos Best Seller en este mes que han sido el Yogur de fruta, la Sopa
-- Las manzanas y el detergente. Todos ellos de marcas diferentes.

-- Eliminar
SELECT 
	fv.FK_PRODUCTO, 
	fv.IMPORTE,
	df.FINDE AS FIN_DE_SEMANA, -- booleano que nos dice True si es Fin de Semana y False si no es Fin de Semana
	COUNT(*) OVER (
		PARTITION BY df.FINDE
	) AS total_ventas_por_tipo_dia 
FROM FACT_VENTAS fv 
JOIN DIM_FECHA df 
	ON fv.FK_FECHA = df.PK_FECHA 
	
-- Fin de Semana
SELECT
    df.FINDE AS FIN_DE_SEMANA,
    COUNT(*) AS numero_ventas,
    SUM(fv.IMPORTE) AS importe_total
FROM FACT_VENTAS fv
JOIN DIM_FECHA df
    ON fv.FK_FECHA = df.PK_FECHA
GROUP BY df.FINDE;

-- Se realizaron 347 ventas durante la semana y 153 durante el fin de semana, por lo que
-- podemos sacar la conclusión de que este mes se vendió más durante el fin de semana que
-- durante la semana.

SELECT
    fv.FK_PRODUCTO,
    fv.IMPORTE,
    df.FINDE AS FIN_DE_SEMANA,
    RANK() OVER (
        PARTITION BY df.FINDE
        ORDER BY fv.IMPORTE DESC
    ) AS ranking_importe_por_tipo_dia
FROM FACT_VENTAS fv
JOIN DIM_FECHA df
    ON fv.FK_FECHA = df.PK_FECHA;

-- Ranking de ventas en función de la Localización.
SELECT
    dl.PK_LOCALIZACION,
    dl.NOMBRE,
    dl.PROVINCIA,
    fv.FK_PRODUCTO,
    COUNT(*) AS numero_ventas,
    RANK() OVER (
        PARTITION BY dl.PK_LOCALIZACION
        ORDER BY COUNT(*) DESC
    ) AS ranking_localizaciones
FROM FACT_VENTAS fv
JOIN DIM_LOCALIZACION dl
    ON fv.FK_LOCALIZACION = dl.PK_LOCALIZACION
GROUP BY
    dl.PK_LOCALIZACION,
    dl.NOMBRE,
    dl.PROVINCIA,
    fv.FK_PRODUCTO
ORDER BY
    ranking_localizaciones;

-- VIEW para el ranking de localizaciones con mayores ventas.
CREATE VIEW view_ranking_localizaciones AS 
SELECT
    dl.PK_LOCALIZACION,
    dl.NOMBRE,
    dl.PROVINCIA,
    fv.FK_PRODUCTO,
    COUNT(*) AS numero_ventas,
    RANK() OVER (
        PARTITION BY dl.PK_LOCALIZACION
        ORDER BY COUNT(*) DESC
    ) AS ranking_localizaciones
FROM FACT_VENTAS fv 
JOIN DIM_LOCALIZACION dl 
    ON fv.FK_LOCALIZACION = dl.PK_LOCALIZACION
GROUP BY
    dl.PK_LOCALIZACION,
    dl.NOMBRE,
    dl.PROVINCIA,
    fv.FK_PRODUCTO
;

-- Consulta
SELECT *
FROM view_ranking_localizaciones vrl 
WHERE ranking_localizaciones <= 4
ORDER BY ranking_localizaciones;

-- A partir de los análisis exploratorios realizados previamente (EDA), se consolidan las métricas más relevantes en una vista 
-- resumen que permite una lectura rápida del rendimiento comercial por provincia.

-- VIEW resumen por provincia y categoría de producto.

CREATE VIEW vw_resumen_ventas_provincia AS
SELECT
    dl.PROVINCIA,
    COUNT(*) AS numero_ventas,
    SUM(fv.IMPORTE) AS importe_total,
    ROUND(AVG(fv.IMPORTE), 2) AS importe_medio,
    CASE
        WHEN COUNT(*) >= 100 THEN 'Alta demanda'
        WHEN COUNT(*) BETWEEN 50 AND 99 THEN 'Demanda media'
        ELSE 'Baja demanda'
    END AS nivel_demanda
FROM FACT_VENTAS fv
JOIN DIM_LOCALIZACION dl
    ON fv.FK_LOCALIZACION = dl.PK_LOCALIZACION
GROUP BY
    dl.PROVINCIA;

SELECT *
FROM vw_resumen_ventas_provincia
ORDER BY importe_total DESC;

DROP VIEW IF EXISTS vw_resumen_ventas_provincia;

CREATE VIEW vw_resumen_ventas_provincia AS
SELECT
    dl.PROVINCIA,
    COUNT(*) AS numero_ventas,
    SUM(fv.IMPORTE) AS importe_total,
    ROUND(AVG(fv.IMPORTE), 2) AS importe_medio,
    CASE
        WHEN COUNT(*) >= 100 THEN 'Alta demanda'
        WHEN COUNT(*) BETWEEN 60 AND 99 THEN 'Demanda media'
        ELSE 'Baja demanda'
    END AS nivel_demanda
FROM FACT_VENTAS fv
JOIN DIM_LOCALIZACION dl
    ON fv.FK_LOCALIZACION = dl.PK_LOCALIZACION
GROUP BY
    dl.PROVINCIA;

SELECT * 
FROM vw_resumen_ventas_provincia vrvp
ORDER BY numero_ventas DESC;

-- El análisis final permite visualizar los diferentes volumenes de facturación en función de las diferentes 
-- ciudades:
-- La Ciudad con mayor volumen de ventas es Madrid con una facturación mucho mayor al resto de Provincias.
-- Podemos observar también que el volumen de demanda es muy similar entre las Ciudades de Valencia, Bilbao, Sevilla y Málaga.
-- La vista resumen facilita la detección de zonas con alta y baja demanda.
-- Por otro lado, también podemos observar que el importe_medio de las compras de los clientes es mayor en las ciudades de 
-- Zaragoza y Málaga.
-- Como conclusión de negocio, la segunda ciudad con más población de España (Barcelona), es la que tiene el nivel de demanda 
-- más bajo y también la que tiene el importe_medio más bajo. Por ello, habría que valorar cuál puede ser el motivo, implementar
-- estrategias de marketing más orientadas al público de Barcelona o valorar si es rentable mantener el supermercado abierto en 
-- esta ubicación.




