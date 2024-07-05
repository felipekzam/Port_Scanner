#!/bin/bash

if ! command -v lolcat &> /dev/null; then
    echo "Erro: lolcat não encontrado. Instale-o com 'sudo apt install lolcat' (ou equivalente) antes de usar este script."
    exit 1
fi
if ! command -v hping3 &> /dev/null; then
    echo "Erro: hping3 não encontrado. Instale-o com 'sudo apt install hping3' (ou equivalente) antes de usar este script."
    exit 1
fi

function scan_ports() {
    local scan_type="$1"
    local port="$2"
    local target="$3"
    local timeout="$4"

    case $scan_type in
        SYN)
            hping3 -S -p "$port" -c 1 "$target" --timeout "$timeout" 2>/dev/null | grep flags=SA
            ;;
        UDP)
            result=$(hping3 -2 -p "$port" -c 1 "$target" --timeout "$timeout" 2>&1)
            if echo "$result" | grep -q "Unreachable"; then
                echo "Porta $port: Inacessível (Unreachable)" | lolcat
            elif echo "$result" | grep -vq "filtered"; then
                echo "Porta $port: Aberta" | lolcat
            fi
            ;;
        *)
            echo "Tipo de scan inválido." | lolcat
            return 1
            ;;
    esac
}

function handle_interrupt() {
    echo -e "\nScan interrompido pelo usuário." | lolcat
    exit 1
}

trap handle_interrupt INT

echo "Port Scanner" | lolcat
echo "Este script realiza um scan de portas em um alvo especificado.\n" | lolcat

while true; do
    echo "Escolha uma opção:" | lolcat
    echo "  1 - Scan de uma porta específica" | lolcat
    echo "  2 - Scan de um intervalo de portas" | lolcat
    read option

    echo "Escolha o tipo de scan:" | lolcat
    echo "  1 - SYN scan (padrão)" | lolcat
    echo "  2 - UDP scan" | lolcat
    read scan_choice

    scan_type="SYN"
    if [ "$scan_choice" == "2" ]; then
        scan_type="UDP"
    fi

    # Tempo limite (em milissegundos)
    timeout=5000

    echo -n "Digite o endereço IP ou nome de host alvo: " | lolcat
    read target

    if [[ "$target" =~ [a-zA-Z] ]]; then
        target=$(dig +short "$target" | head -n1)
        if [ -z "$target" ]; then
            echo "Erro: não foi possível resolver o nome de domínio '$target'." | lolcat
            exit 1
        fi
    fi

    case $option in
        1)
            echo -n "Digite o número da porta: " | lolcat
            read port
            if scan_ports "$scan_type" "$port" "$target" "$timeout"; then
                echo "Porta $port: Aberta" | lolcat
            else
                echo "Porta $port: Fechada ou não encontrada" | lolcat
            fi
            ;;
        2)
            echo -n "Digite o intervalo de portas (ex: 1 65000): " | lolcat
            read port_range

            total_ports=$(echo "$port_range" | awk -F '[- ]' '{print $2 - $1 + 1}')
            current_port=0
            open_ports_found=false

            for port in $(seq $port_range); do
                if scan_ports "$scan_type" "$port" "$target" "$timeout"; then
                    echo "Porta $port: Aberta" | lolcat
                    open_ports_found=true
                fi
                current_port=$((current_port + 1))
                percentage=$((current_port * 100 / total_ports))
                echo -ne "Progresso: $percentage%\r" | lolcat
            done

            echo "" 

            if ! $open_ports_found; then
                echo "Nenhuma porta aberta encontrada no intervalo especificado." | lolcat
            fi
            ;;
        *)
            echo "Opção inválida." | lolcat
            ;;
    esac

    echo -n "Deseja realizar outra pesquisa? (s/n): " | lolcat
    read resposta
    if [ "$resposta" != "s" ]; then
        break
    fi
done
