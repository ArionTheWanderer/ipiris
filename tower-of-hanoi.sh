#!/bin/bash

# При получении сигнала SIGINT (Ctrl+C) вывести подсказку для завершения сценария.
trap 'echo ""; echo "Чтобы завершить работу сценария, введите символ «q» или «Q»";' SIGINT

# Высота башен (количество строк для вывода стеков).
MAX_HEIGHT=8

# Инициализация стеков. Cтеки хранятся в виде массива, где элемент с индексом 0 – вершина стека.
stackA=(1 2 3 4 5 6 7 8)
stackB=()
stackC=()

# Номер текущего хода.
move=1

# Функция для вывода состояния башен.
print_towers() {
  # Для каждого из рядов выводятся по три элемента.
  # Если в стеке меньше элементов, то верхние строки выводятся пустыми.
  for (( row=1; row<=MAX_HEIGHT; row++ )); do
    line=""
    for stack in A B C; do
      # Получение значения соответствующего стека.
      case "$stack" in
        A) arr=("${stackA[@]}") ;;
        B) arr=("${stackB[@]}") ;;
        C) arr=("${stackC[@]}") ;;
      esac
      len=${#arr[@]}
      # Число пустых строк сверху = MAX_HEIGHT - len.
      empty_rows=$(( MAX_HEIGHT - len ))
      if (( row <= empty_rows )); then
        cell="| |"
      else
        # Индекс элемента для вывода: смещение = row - empty_rows - 1.
        index=$(( row - empty_rows - 1 ))
        cell="|${arr[$index]}|"
      fi
      line+="$cell  "
    done
    echo "$line"
  done
  echo "+-+  +-+  +-+"
  echo " A    B    C "
}

# Основной игровой цикл.
while true; do
  echo "Ход № $move"
  print_towers
  # Запрос ввода: ожидается ввод двух букв (названия стека-отправителя и стека-получателя).
  read -rp "Ход № $move (откуда, куда): " input

  # Удаление всех пробелов.
  trimmed=$(echo "$input" | tr -d '[:space:]')

  # Если введён q или Q - завершение сценария со статусом 1.
  if [[ "$trimmed" =~ ^[qQ]$ ]]; then
    echo "Выход из игры."
    exit 1
  fi

  # Проверка: после удаления пробелов должно остаться ровно 2 символа.
  if [[ ${#trimmed} -ne 2 ]]; then
    echo "Некорректный ввод. Попробуйте снова."
    continue
  fi

  # Извлечение первого символа (из источника) и второго (из приёмника).
  src=${trimmed:0:1}
  dst=${trimmed:1:1}
  # Приводим к верхнему регистру
  src=$(echo "$src" | tr '[:lower:]' '[:upper:]')
  dst=$(echo "$dst" | tr '[:lower:]' '[:upper:]')

  # Проверка: должны быть введены корректные имена стеков (A, B или C).
  if [[ ! "$src" =~ ^[ABC]$ ]] || [[ ! "$dst" =~ ^[ABC]$ ]]; then
    echo "Некорректный ввод. Допустимы только буквы A, B, C. Попробуйте снова."
    continue
  fi

  # Проверка: нельзя перемещать диск в тот же стек.
  if [[ "$src" == "$dst" ]]; then
    echo "Источник и получатель должны быть различны. Попробуйте снова."
    continue
  fi

  case "$src" in
    A) src_len=${#stackA[@]};;
    B) src_len=${#stackB[@]};;
    C) src_len=${#stackC[@]};;
  esac

  # Проверка: исходный стек не должен быть пуст
  if (( src_len == 0 )); then
    echo "Стек $src пуст. Попробуйте снова."
    continue
  fi

  case "$src" in
    A) disk=${stackA[0]};;
    B) disk=${stackB[0]};;
    C) disk=${stackC[0]};;
  esac

  case "$dst" in
    A) dst_len=${#stackA[@]};;
    B) dst_len=${#stackB[@]};;
    C) dst_len=${#stackC[@]};;
  esac

  # Проверка: если приёмник не пуст, то перемещаемый диск должен быть меньше верхнего диска приёмника.
  if (( dst_len > 0 )); then
    case "$dst" in
      A) dest_top=${stackA[0]};;
      B) dest_top=${stackB[0]};;
      C) dest_top=${stackC[0]};;
    esac
    if (( disk > dest_top )); then
      echo "Такое перемещение запрещено! Перемещаемый диск должен быть меньше верхнего диска приёмника."
      continue
    fi
  fi

  # Перемещение: удаление диска из источника и добавление его на вершину приёмника.
  case "$src" in
    A) stackA=("${stackA[@]:1}");;
    B) stackB=("${stackB[@]:1}");;
    C) stackC=("${stackC[@]:1}");;
  esac

  case "$dst" in
    A) stackA=("$disk" "${stackA[@]}");;
    B) stackB=("$disk" "${stackB[@]}");;
    C) stackC=("$disk" "${stackC[@]}");;
  esac

  # Увеличение номера хода.
  ((move++))

  # Проверка условия победы: если в стеке B или C оказались все 8 дисков, то игрок побеждает
  if (( ${#stackB[@]} == MAX_HEIGHT )) || (( ${#stackC[@]} == MAX_HEIGHT )); then
    echo "Поздравляем, вы выиграли!"
    print_towers
    exit 0
  fi

done
