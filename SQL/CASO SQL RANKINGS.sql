/*-------------------------------------------------------------------------------------------------------------------------------------------------------
EJERCICIO 1,PASO 1 SEGMENTACIÓN -> VAMOS AVERIGUAR AQUELLOS CLIENTES QUE SE GASTAN MAS DINERO EN NUESTRA TIENDA. PRIMERO CALCULAMOS EL GASTO TOTAL POR CLIENTE
 ------------------------------------------------------------------------------------------------------------------------------------------------------*/

WITH customer_total_spending AS (

SELECT 
    o.customer_id,
    ROUND(SUM(o.total_amount),2) AS total_spending_by_customer,

FROM `mda-online-439606.techzone_dataset.orders` o
INNER JOIN `mda-online-439606.techzone_dataset.products` p
ON o.product_id = p.product_id

GROUP BY 
    o.customer_id
   
ORDER BY 
    total_spending_by_customer DESC
),


/*-----------------------------------------------------------------------------------------------------------------------------------------------------
PASO 2 SEGMENTACIÓN -> SEGEMENTAR ENTRE EL 10% DE LAS PERSONAS QUE MAS GASTO TIENEN,ASIGNNANDOLES EL NOMBRE DE TECH ESTHUSIAST,Y EL TOTAL DE CLIENTES.
-------------------------------------------------------------------------------------------------------------------------------------------------------*/   
Deciles AS(

SELECT
  customer_id,
  total_spending_by_customer,
  NTILE(10) OVER (ORDER BY total_spending_by_customer DESC) AS customer_deciles

FROM customer_total_spending 

ORDER BY total_spending_by_customer DESC
),

segment_creation AS( 

SELECT 
  customer_id,
  total_spending_by_customer,
  customer_deciles,
  CASE
    WHEN customer_deciles = 1 THEN 'TECH ENTHUSIAST'
    WHEN customer_deciles IN (1,2,3,4,5,6,7,8,9,10) THEN 'TOTAL_CLIENTS'
    END AS customer_spending_segmentation,

FROM Deciles

ORDER BY total_spending_by_customer DESC
),

--Segmentación añadiendo el ranking.

SEGMENTATION AS( 

SELECT 
  customer_id,
  total_spending_by_customer,
  customer_deciles,
  customer_spending_segmentation,
  RANK() OVER(PARTITION BY customer_spending_segmentation ORDER BY total_spending_by_customer DESC) as ranking_by_segment

FROM segment_creation

ORDER BY total_spending_by_customer DESC
),


/*-----------------------------------------------------------------------------------------------------------------------------
EJERCICIO 2, SUBCATEGORIAS -> UNA VEZ HEMOS CALCULADO EL GASTO TOTAL POR CLIENTE EN LA TIENDA Y HEMOS SEGMENTADO ENTRE TECH ENTHUSIAST Y EL RESTO DE LA POBLACIÓN, TOCA AVERIGUAR CUALES SON LAS SUBCATEGORIAS DE PRODUCTO QUE DEBEN PRIORIZARSE.
------------------------------------------------------------------------------------------------------------------------------
PASO 1 SUBCATEGORIAS-> CREAR EL DATA SET APROPIADO PARA EMPEZAR A TRABAJAR, AGRUPANDO VARIABLES Y AÑADIENDO NUEVAS COMO LA CANTIDAD TOTAL, QUE MAS TARDE AGRUPAREMOS POR SEGMENTO.
---------------------------------------------------------------------------------------------------------------------------------------------------*/

total_orders AS(

SELECT
  o.order_id,
  o.customer_id,
  o.order_date,
  p.category_id,
  c.category_name,
  SUM(o.quantity) AS total_quantity,
  o.total_amount,
  

FROM `mda-online-439606.techzone_dataset.orders` o
INNER JOIN `mda-online-439606.techzone_dataset.products` p
  ON o.product_id = p.product_id
INNER JOIN `mda-online-439606.techzone_dataset.categories` c
  ON p.category_id = c.category_id

GROUP BY customer_id,o.order_id, o.order_date, p.category_id, o.total_amount, c.category_name

),


/*----------------------------------------------------------------------------------------------------------------------------------------------------
PASO 2 SUBCATEGORIAS -> CREAMOS EL RANKING DE PRODUCTOS MAS DEMANDADOS, SEPARANDO ENTRE LOS DOS SEGEMENTOS QUE HEMOS CREADO ANTERIORMENTE.
------------------------------------------------------------------------------------------------------------------------------------------------------*/

total_quantity_by_categories AS (

SELECT
  s.customer_spending_segmentation,
  t.category_name,
  SUM(t.total_quantity) AS total_quantity_by_category,
  RANK() OVER(PARTITION BY s.customer_spending_segmentation ORDER BY SUM(t.total_quantity) DESC) AS ranking_total_quantity_by_category,
  
FROM total_orders t
JOIN SEGMENTATION s
  ON t.customer_id = s.customer_id

GROUP BY  s.customer_spending_segmentation, t.category_name

ORDER BY ranking_total_quantity_by_category ASC

),

-- ORDENAMOS RANKING, LO ACORTAMOS Y QUITAMOS NÚMEROS DUPLICADOS.

SUBCATEGORIES AS(

SELECT 
  customer_spending_segmentation,
  category_name,
  total_quantity_by_category,
  ROW_NUMBER() OVER (PARTITION BY customer_spending_segmentation ORDER BY total_quantity_by_category DESC) AS ranking_subcategory

FROM total_quantity_by_categories

WHERE ranking_total_quantity_by_category <= 10

ORDER BY  customer_spending_segmentation DESC
),


/*-----------------------------------------------------------------------------------------------------------------------------------------------------
 ESTUDIO ADICIONAL SUBCATEGORIES, PASO 1 -> SEPARANDO LAS SUBCATEGORIAS  EN AÑOS EVALUAR PARA EVALUAR SU CRECIMIENTO
-------------------------------------------------------------------------------------------------------------------------------------------------------*/

total_orders_annual AS(

SELECT
  o.order_id,
  o.customer_id,
  o.order_date,
  EXTRACT(YEAR FROM o.order_date) AS order_year,
  p.category_id,
  c.category_name,
  SUM(o.quantity) AS total_quantity,
  o.total_amount,
  SUM(o.total_amount) AS total_spent,

FROM `mda-online-439606.techzone_dataset.orders` o
INNER JOIN `mda-online-439606.techzone_dataset.products` p
  ON o.product_id = p.product_id
INNER JOIN `mda-online-439606.techzone_dataset.categories` c
  ON p.category_id = c.category_id

GROUP BY o.order_id, o.customer_id, o.order_date, p.category_id, o.total_amount, c.category_name
),


/*----------------------------------------------------------------------------------------------------------------------------
 ESTUDIO ADICIONAL SUBCATEGORIAS, PASO 2 -> CREAMOS EL RANKING DE SUBCATEGORIAS MAS DEMANDADAS TANTO EN EL AÑO 2023 Y 2024 
----------------------------------------------------------------------------------------------------------------------------*/

total_quantity_by_categories_annual AS (

SELECT
  ta.order_year,
  s.customer_spending_segmentation,
  ta.category_name,
  SUM(ta.total_quantity) AS total_quantity_by_category,
  RANK() OVER(PARTITION BY ta.order_year, s.customer_spending_segmentation ORDER BY SUM(ta.total_quantity) DESC) AS ranking_total_quantity_by_category,

FROM total_orders_annual ta
JOIN SEGMENTATION s
  ON ta.customer_id = s.customer_id

GROUP BY ta.order_year, s.customer_spending_segmentation, ta.category_name

),

-- ORDENAMOS EL RANKING , LO LIMITAMOS Y ELIMINAMOS PUESTOS DUPLICADOS PARA AMBOS AÑOS

SUBCATEGORIES_ANNUAL AS(

SELECT 
  order_year,
  customer_spending_segmentation,
  category_name,
  total_quantity_by_category,
  ROW_NUMBER() OVER (PARTITION BY order_year, customer_spending_segmentation ORDER BY total_quantity_by_category DESC) AS ranking_subcategory

FROM total_quantity_by_categories_annual

WHERE ranking_total_quantity_by_category <= 10

ORDER BY order_year DESC,  total_quantity_by_category DESC
),



/*---------------------------------------------------------------------------------------------------------------------------------------------------
EJERCICIO 3, CÁLCULO DEL CLV Y CAC -> PROCEDEMOS A EL CALCULO DEL CLV Y CAC POR CADA SEGEMENTO
-------------------------------------------------------------------------------------------------------------------------------------------------------
PASO 1 CLV Y CAC -> VAMOS A CREAR UN DATASET CON VARIABLES QUE NOS ESPECIFIQUEN PARA CADA CONSUMIDOR LA CANTIDAD DE COMPRAS, EL GASTO TOTAL Y SU GASTO PROMEDIO POR COMPRA.*/
---------------------------------------------------------------------------------------------------------------------------------------------------------

shopping_customer AS (

SELECT 
  o.customer_id,
  COUNT(o.order_id) AS total_purchase_count,
  ROUND(SUM(o.total_amount),2) AS total_spending,
  ROUND(AVG(o.total_amount),2) AS average_spending_per_purchase

FROM `mda-online-439606.techzone_dataset.orders` o

GROUP BY o.customer_id

ORDER BY total_spending DESC
),

/*-----------------------------------------------------------------------------------------------------------------------------------
PASO 2 CLV Y CAC-> UNA VEZ SACADO VARIABLES ÚTILES, VAMOS A CALCULAR EL CLV DE CADA CLIENTE, CLV= GASTO TOTAL* 10% DE BENEFICIO.
-----------------------------------------------------------------------------------------------------------------------------------*/

individual_customer_value AS (

SELECT 
  customer_id,
  total_purchase_count,
  total_spending,
  average_spending_per_purchase,
  ROUND((total_spending * 0.10),2) as customer_value,

FROM shopping_customer

GROUP BY customer_id, total_purchase_count,total_spending,average_spending_per_purchase

ORDER BY customer_value DESC 
),


/*----------------------------------------------------------------------------------------------------------------------------------------------------
PASO 3 CLV Y CAC -> UNA VEZ CALCULADO EL CLV INDIVUDAL, PROCEDEMOS A DETERMINAR UN CLV PARA CADA SEGMENTO. LO HAREMOS ELABORANDO UNA MEDIA GENERAL,PARA ESTUDIAR SU VALOR MEDIO POR SEGMENTO.
----------------------------------------------------------------------------------------------------------------------------------------------------*/

CLV_BY_SEGMENT AS (

SELECT 
  s.customer_spending_segmentation,
  ROUND(SUM(cv.customer_value),2) AS total_clv_segment,
  ROUND(AVG(cv.customer_value),2) AS average_clv_segment

FROM individual_customer_value cv
INNER JOIN SEGMENTATION s
  ON cv.customer_id = s.customer_id

GROUP BY s.customer_spending_segmentation
),

/*----------------------------------------------------------------------------------------------------------------------------
 ->PASO 4 CLV Y CAC -> DETERMINAR EL CAC APLICANDO UNA RELACION CLV:CAC = 3:1 EN CADA SEGMENTO.
 -----------------------------------------------------------------------------------------------------------------------------*/

CAC_BY_SEGMENT AS (

SELECT 
  customer_spending_segmentation,
  average_clv_segment,
  ROUND(average_clv_segment / 3, 2) AS recommended_cac

FROM CLV_BY_SEGMENT

),



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
ESTUDIO ADICIONAL CLV, PASO 1 -> POR ÚTIMO,COMO ESTUDIO ADICIONAL, VAMOS A REALIZAR UNA COMPARACION ENTRE AÑOS PARA VER LOS PORCENTAJES DE CRECIMIENTO O DESCENSO DEL VALOR DE CADA INDIVIDUO Y DEL SEGMENTO EN GENERAL.
-------------------------------------------------------------------------------------------------------------------------------------------------------*/

annual_shopping_customer AS (

SELECT 
  o.customer_id,
  EXTRACT(YEAR FROM o.order_date) AS order_year,
  COUNT(o.order_id) AS total_purchase_count,
  ROUND(SUM(o.total_amount),2) AS total_spending,
  ROUND(AVG(o.total_amount),2) AS average_spending_per_purchase

FROM `mda-online-439606.techzone_dataset.orders` o

GROUP BY o.customer_id, EXTRACT(YEAR FROM o.order_date)

ORDER BY order_year DESC,total_spending DESC
),

/*-----------------------------------------------------------------------------------------------------------------------------------------------------
ESTUDIO ADICIONAL CLV PASO 2 -> UNA VEZ AÑADIDO LA VARIABLE FECHA, VAMOS A CALCULAR EL CLV DE CADA CLIENTE POR AÑO , A COMPARARLOS Y HACER UN RANKING PARA ESTUDIAR CUALES HAN CRECIDO MÁS DE UN AÑO A OTRO.
-------------------------------------------------------------------------------------------------------------------------------------------------------*/

individual_customer_value_per_year AS (

SELECT 
  customer_id,
  order_year,
  total_purchase_count,
  total_spending,
  average_spending_per_purchase,
  ROUND((total_spending * 0.10),2) as customer_value_per_year,

FROM annual_shopping_customer sc

GROUP BY customer_id,order_year,total_purchase_count,total_spending,average_spending_per_purchase

ORDER BY order_year DESC,customer_value_per_year DESC 
),

--DATASET DE DIFERENCIAS CON RESPECTO AL AÑO ANTERIOR.

customer_value_growth AS (

SELECT 
  customer_id,
  MAX(CASE WHEN order_year = 2023 THEN customer_value_per_year END) AS customer_value_2023,
  MAX(CASE WHEN order_year = 2024 THEN customer_value_per_year END) AS customer_value_2024,
  ROUND(COALESCE(MAX(CASE WHEN order_year = 2024 THEN customer_value_per_year END), 0) - COALESCE(MAX(CASE WHEN order_year =  
  2023  THEN customer_value_per_year END), 0),2) AS growth_difference

FROM individual_customer_value_per_year

GROUP BY customer_id

ORDER BY growth_difference DESC

),

-- RANKING DE MAYOR CRECIMIENTO.

ranked_customer_growth AS (

SELECT 
  customer_id,
  customer_value_2023,
  customer_value_2024,
  growth_difference,
  RANK() OVER (ORDER BY growth_difference DESC) AS growth_rank

FROM customer_value_growth

WHERE customer_value_2023 IS NOT NULL AND customer_value_2024 IS NOT NULL -- Eliminamos clientes con nulos

ORDER BY growth_rank

),

/*------------------------------------------------------------------------------------------------------------------------------------------------------
ESTUDIO ADICIONAL CLV PASO 3 -> UNA VEZ CALCULADO EL CLV INDIVUDAL ANUAL, PROCEDEMOS A DETERMINAR UN CLV PARA CADA SEGMENTO DIVIDIENDOLOS POR AÑOS PARA POSTERIORMENTE  ESTUDIAR SU CRECIMIENTO.
------------------------------------------------------------------------------------------------------------------------------------------------------*/

clv_by_segment_and_year AS (

SELECT 
  s.customer_spending_segmentation,
  cv.order_year,
  ROUND(SUM(cv.customer_value_per_year),2) AS total_clv_segment,
  ROUND(AVG(cv.customer_value_per_year),2) AS average_clv_segment

FROM individual_customer_value_per_year cv
INNER JOIN SEGMENTATION s
  ON cv.customer_id = s.customer_id

GROUP BY s.customer_spending_segmentation, cv.order_year
),


/*-------------------------------------------------------------------------------------------------------------------------------------------------
PASO 4 ESTUDIO ADICIONAL CLV -> POR ÚTIMO, VAMOS A REALIZAR UNA COMPARACION ENTRE AÑOS PARA VER LOS PORCENTAJES DE CRECIMIENTO O DESCENSO DE CADA SEGMENTO Y TENER UNA VISION MÁS CLARA.
---------------------------------------------------------------------------------------------------------------------------------------------------*/

CLV_SEGMENTS_COMPARISION AS (

SELECT 
  c1.customer_spending_segmentation,
  ROUND(c1.total_clv_segment,2) AS total_clv_2024,
  ROUND(c2.total_clv_segment,2) AS total_clv_2023,
  ROUND(c1.total_clv_segment - c2.total_clv_segment,2) AS clv_difference,
  ROUND(((c1.total_clv_segment - c2.total_clv_segment) / c2.total_clv_segment) * 100, 2) AS clv_percentage_change,
  ROUND(c1.total_clv_segment + c2.total_clv_segment,2) AS clv_total_sum,

FROM clv_by_segment_and_year c1
JOIN clv_by_segment_and_year c2
ON c1.customer_spending_segmentation = c2.customer_spending_segmentation

WHERE c1.order_year = 2024 AND c2.order_year = 2023

)

SELECT * 

FROM SEGMENTATION

/*-------------------------------------------------------------------------------------------------------------------------------------------------------
FIN DEL ESTUDIO.
-------------------------------------------------------------------------------------------------------------------------------------------------------*/