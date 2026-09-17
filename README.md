# Atividade-FAP-SQL
Objetivo: Aplicar comandos SQL estruturados no DuckDB para ingerir, integrar, limpar, enriquecer e analisar os dados de acidentes da Polícia Rodoviária Federal dos anos de 2023, 2024 e 2025.

Entregável Esperado: Um arquivo .sql organizado, comentado e executável sequencialmente, contendo todos os comandos utilizados.


Parte 1: Ingestão e Integração de Dados
Você deverá importar os três arquivos CSV (datatran2023.csv, datatran2024.csv, datatran2025.csv) para o DuckDB.

Tarefa do Aluno:

Utilize a função read_csv_auto para carregar as três bases de dados.

Crie uma única tabela principal chamada acidentes_prf_historico unindo os dados dos três anos (utilize o comando UNION ALL).

Parte 2: Limpeza e Seleção de Colunas
Para otimizar o processamento e focar nas variáveis explicativas do problema de negócio (identificação de fatores associados a acidentes fatais), você deve descartar colunas administrativas e geodésicas que não serão utilizadas na modelagem.

Tarefa do Aluno: Crie uma View chamada vw_acidentes_limpa a partir da tabela principal, removendo explicitamente as seguintes colunas desnecessárias para esta análise descritiva:

latitude e longitude (dados geodésicos granulares demais para o agrupamento atual).

regional, delegacia e uop (dados administrativos da PRF, o foco será em uf, br e municipio).

Parte 3: Engenharia de Recursos (Criação de Novas Colunas)
Você deverá usar comandos condicionais e funções de data para criar variáveis que facilitem as respostas às questões de negócio.

Tarefa do Aluno: Ainda na View vw_acidentes_limpa (ou criando uma nova View estendida chamada vw_acidentes_enriquecida), adicione as seguintes colunas usando a declaração CASE WHEN ou funções de extração de data:

acidente_fatal: Variável-alvo binária. Atribuir 1 se a coluna mortos for maior ou igual a 1; caso contrário, 0.

ano_acidente e mes_acidente: Extraídos a partir da coluna data_inversa.

fim_de_semana: Variável binária. Atribuir 1 se o dia_semana for sábado ou domingo; caso contrário, 0.

data_comemorativa: Criar uma categoria sinalizando datas de alto fluxo. Exemplo: Atribuir 'Fim de Ano' para acidentes entre 20/12 e 02/01, 'Carnaval' (aproximar para os meses de fevereiro/março de acordo com o ano), e 'Normal' para o restante dos dias.

Parte 4: Questões de Negócio (Consultas Analíticas)
Com a base consolidada, limpa e enriquecida, crie consultas em SQL (SELECT, GROUP BY, HAVING, ORDER BY, funções de agregação, subqueries ou WITH) para responder aos seguintes desafios:

Nível 1: Visão Geral e Temporal

1. Tendência Anual e Severidade: Construa uma consulta que retorne, para cada ano (2023, 2024 e 2025): o total de acidentes, o total de vítimas fatais (soma de mortos) e a taxa global de letalidade (percentual de acidentes fatais em relação ao total de acidentes). A proporção de acidentes fatais está aumentando, diminuindo ou estável ao longo dos anos?

2. Sazonalidade Mensal das Ocorrências: Agrupe os dados pelo mes_acidente. Qual mês apresenta a maior taxa de letalidade ao longo desses três anos? Esse pico coincide com os tradicionais períodos de férias de meio ou final de ano?

3. A Influência da Luminosidade (Fase do Dia): Agrupe os acidentes pela variável fase_dia (Pleno dia, Plena noite, Amanhecer, Anoitecer). Embora o volume absoluto de acidentes possa ser maior durante o dia, a proporção (percentual) de acidentes fatais é maior à noite? Comprove com os indicadores construídos.

4. O Impacto dos Finais de Semana: Utilizando a variável binária fim_de_semana criada na etapa de preparação, compare a taxa de letalidade dos acidentes que ocorrem nos finais de semana versus dias úteis. O risco relativo de um acidente ser fatal muda consideravelmente aos finais de semana?

Nível 2: Análise de Risco (Cálculo de Lift e Fatores de Causa)

5. O Perigo Oculto na Dinâmica da Colisão (Tipo de Acidente): Calcule a taxa global de letalidade da base. Em seguida, calcule o Lift para a variável tipo_acidente (taxa de letalidade do tipo / taxa global). Qual é a dinâmica de colisão (ex: colisão frontal, capotamento) que mais eleva a probabilidade de uma morte em relação à média global? (Filtre apenas tipos com pelo menos 100 registros usando HAVING).

6. Ranking de Causas Associadas à Letalidade: Repita a lógica do Lift, mas agora agrupe pela causa_acidente. Retorne as 5 causas presumíveis com o maior Lift. A ingestão de álcool ou a ultrapassagem indevida aparecem nesse top 5?

7. Análise da Infraestrutura (Traçado da Via): Avalie a variável tracado_via. A taxa de letalidade é estatisticamente pior em trechos de "Reta" ou em trechos de "Curva"? Filtre para exibir apenas os traçados com mais de 500 acidentes registrados no total.

Nível 3: Análise Multivariada (Cruzamentos de Variáveis)

8. Condições Agravantes (Pista vs. Clima): Cruze as variáveis tipo_pista e condicao_meteorologica. Descubra qual combinação específica gera a maior taxa de letalidade. Considere apenas combinações que possuam um volume mínimo de 50 registros para evitar falsos padrões de subgrupos muito pequenos.

9. Pontos Críticos Noturnos (BR x Fase do Dia): Filtre a base apenas para acidentes ocorridos à noite (fase_dia igual a 'Plena Noite'). Crie um ranking das 10 rodovias (BRs) no Brasil com o maior número absoluto de vítimas fatais especificamente nessa condição de luminosidade.

10. O Efeito de Períodos Festivos: Utilizando a coluna data_comemorativa criada na Parte 3, compare o total de acidentes, o total de mortos e a taxa de letalidade entre períodos como 'Fim de Ano', 'Carnaval' e dias 'Normais'. Há um aumento expressivo no volume e na gravidade?

Nível 4: Casos Críticos e Foco Geográfico

11. Acidentes de Altíssima Gravidade (Múltiplas Vítimas): Filtre a base para trazer apenas as ocorrências de extrema gravidade (onde o número de mortos for maior ou igual a 3). Qual é o estado (uf) que lidera esse triste ranking absoluto? E, nesse grupo restrito, qual é a principal causa relatada?

12. Direcionamento Regional em Pernambuco (Alocação de Viaturas): A superintendência da PRF precisa planejar a alocação de viaturas de resgate no estado de Pernambuco (PE). Escreva uma consulta filtrando apenas uf = 'PE' e traga o ranking dos 5 municípios que concentraram o maior número absoluto de acidentes fatais somando os anos de 2024 e 2025.

Diretrizes de Entrega para os Alunos (Avaliação)
O arquivo .sql deve iniciar com um cabeçalho documentando o autor, a ferramenta utilizada (DuckDB) e as fontes de dados.

Antes de cada comando SELECT, o aluno deve incluir um comentário breve (--) explicando qual questão de negócio a consulta está respondendo.

O script deve ser reprodutível: qualquer pessoa executando o arquivo de ponta a ponta não deve encontrar erros de sintaxe ou de tabelas inexistentes. 
