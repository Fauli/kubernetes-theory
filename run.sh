#!/bin/bash

PRESENTATIONS=(
    "operator-presentation.md:Kubernetes Operator Internals"
    "crd-design.md:CRD Design Patterns"
    "testing-operators.md:Testing Operators"
    "azure-service-operator.md:Azure Service Operator v2 Deep Dive"
    "debugging-operators.md:Debugging Operators (WIP)"
    "admission-webhooks.md:Admission Webhooks (WIP)"
)

show_menu() {
    echo "Available presentations:"
    echo ""
    for i in "${!PRESENTATIONS[@]}"; do
        IFS=':' read -r file desc <<< "${PRESENTATIONS[$i]}"
        printf "  %d) %s\n" "$((i+1))" "$desc"
    done
    echo ""
}

# If argument provided, use it directly
if [[ -n "$1" ]]; then
    case "$1" in
        1|operator) FILE="operator-presentation.md" ;;
        2|crd) FILE="crd-design.md" ;;
        3|testing) FILE="testing-operators.md" ;;
        4|aso) FILE="azure-service-operator.md" ;;
        5|debugging) FILE="debugging-operators.md" ;;
        6|webhooks) FILE="admission-webhooks.md" ;;
        *.md) FILE="$1" ;;
        *)
            echo "Unknown presentation: $1"
            show_menu
            exit 1
            ;;
    esac
else
    show_menu
    read -p "Select presentation [1-6]: " choice

    case "$choice" in
        1) FILE="operator-presentation.md" ;;
        2) FILE="crd-design.md" ;;
        3) FILE="testing-operators.md" ;;
        4) FILE="azure-service-operator.md" ;;
        5) FILE="debugging-operators.md" ;;
        6) FILE="admission-webhooks.md" ;;
        *)
            echo "Invalid selection"
            exit 1
            ;;
    esac
fi

if [[ ! -f "$FILE" ]]; then
    echo "Error: $FILE not found"
    exit 1
fi

echo "Starting: $FILE"
reveal-md "$FILE" --css kubernetes-theme.css
