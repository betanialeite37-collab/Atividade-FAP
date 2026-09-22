-- ============================================================
-- ANÁLISE INTEGRADA DE ACIDENTES RODOVIÁRIOS FEDERAIS
-- Período: 2023 a 2025
-- Autor: Betânia Leite
-- Ferramenta: DuckDB
-- Fonte dos dados: Polícia Rodoviária Federal (PRF)
-- ============================================================

-- PARTE 1 - INGESTÃO E INTEGRAÇÃO DOS DADOS
-- Criação da tabela histórica consolidando os dados de
-- acidentes rodoviários federais de 2023, 2024 e 2025.

CREATE OR REPLACE TABLE acidentes_prf_historico AS

SELECT *
FROM read_csv_auto(
    'dados/datatran2023.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)

UNION ALL

SELECT *
FROM read_csv_auto(
    'dados/datatran2024.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)

UNION ALL

SELECT *
FROM read_csv_auto(
    'dados/datatran2025.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
);

-- Validção da quantidade total de registros após a integração.
SELECT COUNT(*) AS total_registros
FROM acidentes_prf_historico;

-- ============================================================
-- PARTE 2 - LIMPEZA E SELEÇÃO DE COLUNAS
-- ============================================================

-- Criação de uma View removendo as colunas geodésicas
-- e administrativas que não serão utilizadas na análise.

CREATE OR REPLACE VIEW vw_acidentes_limpa AS
SELECT
    * EXCLUDE (
        latitude,
        longitude,
        regional,
        delegacia,
        uop,
        condicao_metereologica
    ),
    condicao_metereologica AS condicao_meteorologica
FROM acidentes_prf_historico;

-- Validação da View após a remoção das colunas desnecessárias.
SELECT *
FROM vw_acidentes_limpa
LIMIT 10;

-- ============================================================
-- PARTE 3 - ENGENHARIA DE RECURSOS
-- ============================================================
-- Criação de variáveis derivadas para apoiar as análises
-- temporais e de letalidade dos acidentes.

CREATE OR REPLACE VIEW vw_acidentes_enriquecida AS
SELECT
    *,

    -- 1 = acidente com pelo menos uma vítima fatal; 0 = sem mortos.
    CASE
        WHEN mortos >= 1 THEN 1
        ELSE 0
    END AS acidente_fatal,

    -- Extração do ano e do mês da data do acidente.
    EXTRACT(YEAR FROM data_inversa) AS ano_acidente,
    EXTRACT(MONTH FROM data_inversa) AS mes_acidente,

    -- 1 = sábado ou domingo; 0 = dia útil.
    CASE
        WHEN LOWER(dia_semana) IN ('sábado', 'domingo') THEN 1
        ELSE 0
    END AS fim_de_semana,

    -- Classificação aproximada dos períodos comemorativos.
    CASE
        WHEN
            (EXTRACT(MONTH FROM data_inversa) = 12
             AND EXTRACT(DAY FROM data_inversa) >= 20)
            OR
            (EXTRACT(MONTH FROM data_inversa) = 1
             AND EXTRACT(DAY FROM data_inversa) <= 2)
        THEN 'Fim de Ano'

        WHEN data_inversa BETWEEN DATE '2023-02-18' AND DATE '2023-02-22'
          OR data_inversa BETWEEN DATE '2024-02-10' AND DATE '2024-02-14'
          OR data_inversa BETWEEN DATE '2025-03-01' AND DATE '2025-03-05'
        THEN 'Carnaval'
        ELSE 'Normal'
    END AS data_comemorativa

FROM vw_acidentes_limpa;

-- Validação das categorias de datas comemorativas.
SELECT
    data_comemorativa,
    COUNT(*) AS total_acidentes
FROM vw_acidentes_enriquecida
GROUP BY data_comemorativa
ORDER BY total_acidentes DESC;


-- ============================================================
-- PARTE 4: QUESTÕES DE NEGÓCIO (CONSULTAS ANALÍTICAS)
-- ============================================================

-- ============================================================
-- NIVEL 1 - VISÃO GERAL E TEMPORAL
-- ============================================================

-- ============================================================
-- QUESTÃO 1 - Tendência Anual e Severidade
-- Calcula o total de acidentes, o total de vítimas fatais
-- e a taxa de letalidade para cada ano.
-- ============================================================

SELECT
    ano_acidente,

    COUNT(*) AS total_acidentes,

    SUM(mortos) AS total_vitimas_fatais,

    ROUND(100.0 * SUM(acidente_fatal) / COUNT(*), 2
    ) AS taxa_letalidade_percentual

FROM vw_acidentes_enriquecida

GROUP BY ano_acidente

ORDER BY ano_acidente;

-- ANÁLISE:
-- Entre 2023 e 2025, a taxa de letalidade permaneceu praticamente estável, variando de 7,14% a 7,18%.
-- Em 2024 foi registrado o maior volume de acidentes e de vítimas fatais,porém isso não resultou na maior taxa de letalidade do período.
-- Os resultados indicam estabilidade da severidade dos acidentes ao longo dos três anos analisados.


-- ============================================================
-- QUESTÃO 2 - SAZONALIDADE MENSAL DAS OCORRÊNCIAS
-- Analisa o volume de acidentes, o total de vítimas fatais
-- e a taxa de letalidade em cada mês.
-- ============================================================

SELECT
    mes_acidente,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,

    ROUND(
        100.0 * SUM(acidente_fatal) / COUNT(*),
        2
    ) AS taxa_letalidade_percentual

FROM vw_acidentes_enriquecida

GROUP BY mes_acidente

ORDER BY taxa_letalidade_percentual DESC;

-- ANÁLISE:
-- Maio apresentou a maior taxa de letalidade (7,71%),seguido por junho (7,68%) e julho (7,49%).
-- Dezembro apresentou o maior volume de acidentes (19.989), porém sua taxa de letalidade foi de 7,15%.
-- Portanto, o maior volume de acidentes não corresponde, necessariamente, ao período de maior letalidade.
-- Os resultados mostram maior concentração das taxas de letalidade entre maio e julho.


-- ============================================================
-- QUESTÃO 3 - A Influência da Luminosidade (Fase do Dia)
-- Compara o volume de acidentes e a taxa de letalidade
-- entre as diferentes fases do dia.
-- ============================================================
SELECT
    fase_dia,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    SUM(acidente_fatal) AS total_acidentes_fatais,

    ROUND(
        100.0 * SUM(acidente_fatal) / COUNT(*),
        2
    ) AS taxa_letalidade_percentual

FROM vw_acidentes_enriquecida

GROUP BY fase_dia

ORDER BY taxa_letalidade_percentual DESC;

-- Análise
-- O Amanhecer apresentou a maior taxa de letalidade (11,36%),seguido pela Plena Noite (10,09%).
-- Embora o Pleno dia tenha registrado o maior volume de acidentes,sua taxa de letalidade foi a menor entre as fases analisadas (5,02%).


--==================================================================
-- QUESTÃO 4 - O Impacto dos Finais de Semana
-- Compara a taxa de letalidade entre finais de semana e dias úteis.
--=================================================================
SELECT
    fim_de_semana,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    SUM(acidente_fatal) AS total_acidentes_fatais,
    ROUND(
        100.0 * SUM(acidente_fatal) / COUNT(*),
        2
    ) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY fim_de_semana
ORDER BY taxa_letalidade_percentual DESC;

-- Análise
-- Embora os dias úteis concentrem o maior número absoluto de acidentes, os finais de semana apresentaram maior taxa de letalidade.
-- A taxa foi de 8,43% nos finais de semana, contra 6,56% nos dias úteis.
-- Isso representa uma diferença de 1,87 ponto percentual e uma taxa aproximadamente 29% maior nos finais de semana.
-- Os resultados indicam associação entre os finais de semana e uma maior proporção de acidentes fatais, sem estabelecer relação de causa.


--=================================================================
-- NIVEL 2 - ANALISE DE RISCO (CÁLCULO DE LIFT E FATORES DE CAUSA)
-- ================================================================

-- ============================================================
-- QUESTÃO 5 - TIPO DE ACIDENTE E LIFT
-- Calcula a taxa global de letalidade da base histórica.
-- ============================================================

SELECT
    COUNT(*) AS total_acidentes,
    SUM(acidente_fatal) AS total_acidentes_fatais,
    ROUND(
        100.0 * SUM(acidente_fatal) / COUNT(*),
        2
    ) AS taxa_global_letalidade
FROM vw_acidentes_enriquecida;

-- ============================================================
-- QUESTÃO 5 - Tipo de Acidente e Lift
-- Calcula a taxa de letalidade por tipo de acidente e compara
-- cada resultado com a taxa global por meio do Lift.
-- Considera somente tipos com pelo menos 100 registros.
---- ============================================================

WITH taxa_global AS (
    SELECT
        AVG(acidente_fatal) AS taxa_global
    FROM vw_acidentes_enriquecida
)

SELECT
    tipo_acidente,
    COUNT(*) AS total_acidentes,

    SUM(acidente_fatal) AS acidentes_fatais,

    ROUND(
        100.0 * AVG(acidente_fatal),
        2
    ) AS taxa_letalidade_percentual,

    ROUND(
        AVG(acidente_fatal) / taxa_global.taxa_global,
        2
    ) AS lift

FROM vw_acidentes_enriquecida
CROSS JOIN taxa_global

GROUP BY
    tipo_acidente,
    taxa_global.taxa_global

HAVING COUNT(*) >= 100

ORDER BY lift DESC;

-- Análise
-- A taxa global de letalidade da base foi de aproximadamente 7,16%.
-- Entre os tipos de acidente analisados, a Colisão frontal apresentou a maior taxa de letalidade (29,81%) e o maior Lift (4,16).
-- Isso significa que sua proporção de acidentes fatais foi cerca de 4,16 vezes a taxa global da base.
-- O Atropelamento de Pedestre também apresentou elevada letalidade, com taxa de 28,97% e Lift de 4,04.
-- Esses resultados destacam esses tipos de acidente por apresentarem proporções de fatalidade muito superiores à média geral.


--============================================================
-- QUESTÃO 6 - Ranking de Causas Associadas à Letalidade
-- Calcula o Lift das causas dos acidentes em relação à taxa
-- global de letalidade e retorna as cinco maiores.
--============================================================

WITH taxa_global AS (
    SELECT
        AVG(acidente_fatal) AS taxa_global
    FROM vw_acidentes_enriquecida
)

SELECT
    causa_acidente,
    COUNT(*) AS total_acidentes,
    SUM(acidente_fatal) AS acidentes_fatais,

    ROUND(
        100.0 * AVG(acidente_fatal),
        2
    ) AS taxa_letalidade_percentual,

    ROUND(
        AVG(acidente_fatal) / taxa_global.taxa_global,
        2
    ) AS lift

FROM vw_acidentes_enriquecida
CROSS JOIN taxa_global

GROUP BY
    causa_acidente,
    taxa_global.taxa_global

ORDER BY lift DESC

LIMIT 5;

-- Análise
-- A categoria "Suicídio (presumido)" apresentou a maior taxa de letalidade (50,91%) e o maior Lift (7,11), indicando uma proporção
-- de fatalidade muito superior à taxa global da base.
-- Em seguida, "Pedestre andava na pista" apresentou taxa de 41,44% e Lift de 5,79.
-- Entre as cinco maiores também aparecem situações relacionadas a pedestres e o trânsito na contramão.
-- Destaca-se "Transitar na contramão", com 7.300 acidentes,taxa de letalidade de 28,96% e Lift de 4,04.


--============================================================
-- QUESTÃO 7 - Comparação específica entre Reta e Curva
-- Compara a letalidade dos acidentes registrados
-- exclusivamente nas categorias Reta e Curva.
--============================================================

SELECT
    tracado_via,
    COUNT(*) AS total_acidentes,
    SUM(acidente_fatal) AS acidentes_fatais,
    SUM(mortos) AS total_vitimas_fatais,

    ROUND(
        100.0 * AVG(acidente_fatal),
        2
    ) AS taxa_letalidade_percentual

FROM vw_acidentes_enriquecida

WHERE tracado_via IN ('Reta', 'Curva')

GROUP BY tracado_via

HAVING COUNT(*) > 500

ORDER BY taxa_letalidade_percentual DESC;

-- Análise
-- As retas concentraram o maior número absoluto de acidentes e de vítimas fatais no período analisado.
-- Entretanto, as curvas apresentaram uma taxa de letalidade ligeiramente superior: 7,67%, contra 7,13% nas retas.
-- A diferença observada foi de 0,54 ponto percentual.
-- Portanto, nesta análise descritiva, as curvas apresentaram maior proporção de acidentes fatais, apesar do menor volume
-- absoluto de ocorrências.


--============================================================
-- NIVEL 3 - ANALISE MULTIVARIADA (CRUZAMENTO DE VARIÁVEIS)
--============================================================

-- ============================================================
-- QUESTÃO 8 - CONDIÇÕES AGRAVANTES: PISTA VS. CLIMA
-- Cruza o tipo de pista com a condição meteorológica
-- e identifica as combinações com maior taxa de letalidade.
-- Considera apenas combinações com pelo menos 50 registros.
-- ============================================================

SELECT
    tipo_pista,
    condicao_meteorologica,
    COUNT(*) AS total_acidentes,
    SUM(acidente_fatal) AS acidentes_fatais,
    SUM(mortos) AS total_vitimas_fatais,
    ROUND(
        100.0 * SUM(acidente_fatal) / COUNT(*),
        2
    ) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY
    tipo_pista,
    condicao_meteorologica
HAVING COUNT(*) >= 50
ORDER BY taxa_letalidade_percentual DESC;

-- Análise
-- A combinação de pista Simples com Nevoeiro/Neblina apresentou a maior taxa de letalidade, aproximadamente 13,95%, considerando as combinações com pelo menos 50 registros.
-- Pista Simples com Vento também apresentou taxa elevada, aproximadamente 13,91%, porém com menor volume de ocorrências.
-- A combinação de pista Simples com Céu Claro concentrou um volume muito maior de acidentes, mas apresentou taxa de letalidade inferior às combinações de maior taxa.
-- Os resultados mostram que maior volume de acidentes não implica,necessariamente, maior proporção de acidentes fatais.



-- ============================================================
-- QUESTÃO 9 - PONTOS CRÍTICOS NOTURNOS (BR X FASE DO DIA)
-- Identifica as 10 rodovias com maior número absoluto
-- de vítimas fatais em acidentes ocorridos em Plena Noite.
-- ============================================================

SELECT
    br,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais
FROM vw_acidentes_enriquecida
WHERE fase_dia = 'Plena Noite'
GROUP BY br
ORDER BY total_vitimas_fatais DESC
LIMIT 10;

-- Análise
-- A BR-116 apresentou o maior número absoluto de vítimas fatais em acidentes ocorridos durante a Plena Noite, com 1.190 mortes.
-- A BR-101 ficou em seguida, com 1.076 vítimas fatais, apesar de apresentar maior número de acidentes noturnos que a BR-116.
-- Os resultados identificam as rodovias com maior concentração absoluta de mortes no período noturno.
-- Essa análise não representa uma taxa de risco, pois não considera fatores como extensão da rodovia, tráfego ou volume de veículos.


-- ============================================================
-- QUESTÃO 10 - O EFEITO DE PERÍODOS FESTIVOS
-- Compara o volume de acidentes, o total de vítimas fatais
-- e a taxa de letalidade entre os períodos comemorativos.
-- ============================================================

SELECT
    data_comemorativa,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    SUM(acidente_fatal) AS acidentes_fatais,

    ROUND(
        100.0 * AVG(acidente_fatal),
        2
    ) AS taxa_letalidade_percentual

FROM vw_acidentes_enriquecida

GROUP BY data_comemorativa

ORDER BY taxa_letalidade_percentual DESC;

-- Análise
-- O período de Fim de Ano apresentou a maior taxa de letalidade,com 7,41%, ligeiramente superior ao período Normal (7,16%).
-- O Carnaval apresentou a menor taxa entre os períodos analisados,com 6,63%.
-- Portanto, nos dados de 2023 a 2025, o Carnaval não apresentou aumento da proporção de acidentes fatais em relação ao período Normal.
-- O Fim de Ano apresentou maior letalidade proporcional, embora a diferença em relação ao período Normal tenha sido pequena.


-- ============================================================
-- QUESTÃO 11 - ACIDENTES DE ALTÍSSIMA GRAVIDADE
-- Identifica o estado com maior número de acidentes com
-- três ou mais mortos e a principal causa nesse grupo.
-- ============================================================

WITH acidentes_graves AS (
    SELECT *
    FROM vw_acidentes_enriquecida
    WHERE mortos >= 3
),

estado_lider AS (
    SELECT
        uf,
        COUNT(*) AS total_acidentes_graves
    FROM acidentes_graves
    GROUP BY uf
    ORDER BY total_acidentes_graves DESC
    LIMIT 1
),

principal_causa AS (
    SELECT
        causa_acidente,
        COUNT(*) AS total_ocorrencias
    FROM acidentes_graves
    GROUP BY causa_acidente
    ORDER BY total_ocorrencias DESC
    LIMIT 1
)

SELECT
    e.uf AS estado_lider,
    e.total_acidentes_graves,
    c.causa_acidente AS principal_causa,
    c.total_ocorrencias AS ocorrencias_principal_causa
FROM estado_lider e
CROSS JOIN principal_causa c;

-- Análise
--Minas Gerais (MG) apresentou o maior número de acidentes de altíssima gravidade, com 75 ocorrências envolvendo três ou mais mortos.
-- Considerando o conjunto nacional desses acidentes, "Transitar na contramão" foi a causa mais frequente, com 118 ocorrências.
-- Os resultados destacam MG pela quantidade de acidentes de altíssima gravidade e o trânsito na contramão como a principal causa registrada nesse grupo específico de ocorrências.

-- ============================================================
-- QUESTÃO 12 - DIRECIONAMENTO REGIONAL EM PERNAMBUCO
-- Identifica os 5 municípios de Pernambuco com maior número
-- de acidentes fatais nos anos de 2024 e 2025.
-- ============================================================

SELECT
    municipio,
    COUNT(*) AS total_acidentes_fatais
FROM vw_acidentes_enriquecida
WHERE uf = 'PE'
  AND ano_acidente IN (2024, 2025)
  AND acidente_fatal = 1
GROUP BY municipio
ORDER BY total_acidentes_fatais DESC
LIMIT 5;

-- Análise
-- Recife apresentou o maior número de acidentes fatais em Pernambuco nos anos de 2024 e 2025, com 45 ocorrências.
-- Jaboatão dos Guararapes, Garanhuns e Caruaru aparecem em seguida, empatados com 24 acidentes fatais cada, enquanto Petrolina registrou 23.
-- Os resultados mostram uma maior concentração absoluta de acidentes fatais em Recife entre os municípios analisados no período.