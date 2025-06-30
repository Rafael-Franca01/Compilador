# Compilador PCD

Este repositório contém o código-fonte de um compilador para uma linguagem procedural simples, desenvolvida como um projeto de estudos. O compilador foi construído utilizando as ferramentas **Flex** e **Bison** e gera um código intermediário em C++, que é então compilado para um executável nativo.

A linguagem possui tipagem estática, gerenciamento automático de memória para estruturas complexas e suporte para operações aritméticas, lógicas e de fluxo de controle.

## Funcionalidades da Linguagem

### 1. Tipos de Dados Primitivos
A linguagem suporta os seguintes tipos de dados:
- `int`: Números inteiros (e.g., `10`, `42`).
- `flt`: Números de ponto flutuante (e.g., `3.14`, `99.0`).
- `boo`: Valores booleanos, representados por `true` e `false`.
- `chr`: Caracteres únicos (e.g., `'a'`, `'%'`).
- `str`: Cadeias de caracteres (e.g., `"ola mundo"`).

### 2. Estruturas de Dados
- **Vetores (Arrays de 1D)**: Podem ser declarados com tamanho definido em tempo de compilação ou de execução.
  ```
  int meu_vetor[10];
  ```
- **Matrizes (Arrays de 2D)**: Suportam declaração com tamanho dinâmico e operações aritméticas.
  ```
  flt matriz_a[5][5];
  ```
- **Classes (Structs)**: Permitem a criação de tipos de dados customizados, agrupando variáveis. Os membros podem ser de qualquer tipo, incluindo vetores e matrizes.
  ```
  cls Ponto {
      int x;
      int y;
  };
  Ponto p1;
  p1.x = 10;
  ```

### 3. Variáveis
- Declaração simples: `int i;`
- Declaração com inicialização: `str nome = "Compilador";`
- O compilador gerencia automaticamente a alocação e liberação de memória para strings, vetores e matrizes.

### 4. Operadores

| Operador | Descrição | Tipos Compatíveis |
| :---: | --- | --- |
| `=` | Atribuição. | Todos os tipos (devem ser compatíveis). |
| `+` | **Soma**: `int`, `flt`.<br>**Concatenação**: `str`.<br>**Soma de Matrizes**: `matriz<int>`, `matriz<flt>`. |
| `-` | **Subtração**: `int`, `flt`.<br>**Subtração de Matrizes**: `matriz<int>`, `matriz<flt>`. |
| `*` | **Multiplicação**: `int`, `flt`.<br>**Multiplicação de Matrizes**: `matriz<int>`, `matriz<flt>`. |
| `/` | **Divisão**: `int`, `flt`. |
| `++`, `--` | Incremento e decremento (pré e pós-fixado). | `int`, `flt` |
| `==`, `!=` | Igualdade e Diferença. | `int`, `flt`, `chr`, `boo` |
| `<`, `>`, `<=`, `>=` | Operadores relacionais. | `int`, `flt` |
| `&`, `|`, `~` | AND, OR e NOT lógicos. | `boo` |
| `.` | Acesso a membro de classe/struct. | `cls` |
| `(tipo)` | Conversão explícita de tipo (Type Casting). | `int`, `flt`, `chr` |


### 5. Estruturas de Controle de Fluxo
- **Condicional `if-else`**:
  ```
  if (a > b) {
    prt("a eh maior");
  } helcio { // helcio = else
    prt("b eh maior");
  }
  ```
- **Laço `while`**:
  ```
  whl (i < 10) { // whl = while
    i = i + 1;
  }
  ```
- **Laço `do-while`**:
  ```
  do {
    receba(input);
  } whl (input != 0);
  ```
- **Laço `for`**:
  ```
  for (int j = 0; j < 10; j++) {
    prt(j);
  }
  ```
- **Switch Case**:
  ```
  swc (opcao) { // swc = switch
    cs 1:      // cs = case
      prt("Caso 1");
      brk;
    def:       // def = default
      prt("Default");
  }
  ```
- **Controle de Laço**: `brk` (break) e `cnt` (continue).

### 6. Funções
- Suporte para definição e declaração (protótipos) de funções.
- Parâmetros podem ser de tipos primitivos, vetores (`int v[]`) ou matrizes (`flt m[][]`).
- Funções podem retornar valores de qualquer tipo ou ser `vd` (void).
- A palavra-chave para retorno é `rtn`.

### 7. Entrada e Saída
- `prt(expressao);`: Imprime o valor de uma expressão na saída padrão.
- `receba(variavel);`: Lê um valor da entrada padrão e o armazena em uma variável.

### 8. Comentários
- Comentários de linha única são iniciados com `//`.

## Palavras-Chave da Linguagem

| Palavra-Chave | Equivalente em C/C++ | Descrição |
| --- | --- | --- |
| `main` | `main` | Ponto de entrada principal do programa. |
| `int`, `flt`, `boo`, `chr`, `str`, `vd` | `int`, `float`, `int`, `char`, `char*`, `void` | Tipos de dados. |
| `if` | `if` | Estrutura condicional. |
| `helcio` | `else` | Alternativa da estrutura condicional. |
| `whl` | `while` | Laço de repetição. |
| `do` | `do` | Início de um laço `do-while`. |
| `for` | `for` | Laço de repetição com contador. |
| `swc` | `switch` | Estrutura de seleção múltipla. |
| `cs` | `case` | Rótulo de um caso dentro de um `switch`. |
| `def` | `default` | Rótulo padrão de um `switch`. |
| `brk` | `break` | Sai de um laço ou `switch`. |
| `cnt` | `continue` | Pula para a próxima iteração de um laço. |
| `prt` | `printf`/`std::cout` | Função para imprimir na tela. |
| `receba` | `scanf`/`std::cin` | Função para ler da entrada padrão. |
| `rtn` | `return` | Retorna um valor de uma função. |
| `cls` | `class`/`struct` | Define uma nova estrutura de dados. |
| `true`, `false`| `1`, `0` | Literais booleanos. |

## Como Compilar e Executar

Para compilar o projeto, você precisará do **Flex**, **Bison** e um compilador C++ (como o **g++**).

1.  **Gere os arquivos do analisador com Flex e Bison:**
    ```bash
    bison -d -o y.tab.c syntax.y
    flex -o lex.yy.c lexico.l
    ```
    *O comando `bison -d` cria tanto o `y.tab.c` (código do parser) quanto o `y.tab.h` (cabeçalho com as definições dos tokens), que é necessário para o analisador léxico.*

2.  **Compile o código C++ gerado:**
    ```bash
    g++ -o compilador y.tab.c
    ```
    *Como o arquivo `lex.yy.c` é incluído diretamente no `syntax.y` (`#include "lex.yy.c"`), não é necessário passá-lo como um argumento de compilação separado.*

3.  **Use o compilador para traduzir um código da sua linguagem:**
    ```bash
    ./compilador < seu_codigo.pcd > seu_codigo.c
    ```
    *Substitua `seu_codigo.pcd` pelo nome do seu arquivo de código-fonte.*

4.  **Compile o código C gerado:**
    ```bash
    gcc -o meu_programa seu_codigo.c
    ```

5.  **Execute seu programa!**
    ```bash
    ./meu_programa
    ```

## Exemplo de Código na Linguagem

```
// Arquivo: exemplo.pcd

// Função para calcular o fatorial
int fatorial(int n) {
  if (n <= 1) {
    rtn 1;
  }
  rtn n * fatorial(n - 1);
}

int main() {
  int valor;
  prt("Digite um numero para calcular o fatorial: ");
  receba(valor);

  if (valor < 0) {
    prt("\nNao eh possivel calcular fatorial de numero negativo.");
  } helcio {
    int res = fatorial(valor);
    prt("\nO fatorial de ");
    prt(valor);
    prt(" eh ");
    prt(res);
  }

  prt("\n\n-- Teste de Matrizes --\n");
  int m[2][2];
  m[0][0] = 1;
  m[0][1] = 2;
  m[1][0] = 3;
  m[1][1] = 4;

  int m2[2][2];
  m2[0][0] = 5;
  m2[0][1] = 6;
  m2[1][0] = 7;
  m2[1][1] = 8;
  
  int soma[2][2] = m + m2;
  
  prt("Soma[1][1] = ");
  prt(soma[1][1]); // Deve imprimir 12
}
```
