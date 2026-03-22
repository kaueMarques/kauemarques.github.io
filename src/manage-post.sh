#!/bin/bash
set -e

check_authorization() {
  if [[ "$GITHUB_ACTOR" != "kaueMarques" ]]; then
    echo "⛔ ERRO DE SEGURANÇA: Acesso negado. Apenas o owner do repositório possui permissão para executar esta pipeline."
    exit 1 
  fi
}

setup_variables() {
  HAS_POST_LABEL=$(echo "$LABELS" | grep -i '"post"' || true)
  HAS_EVENTO_LABEL=$(echo "$LABELS" | grep -i '"evento"' || true)
  HAS_NOTE_LABEL=$(echo "$LABELS" | grep -i '"note"' || true)
  HAS_EDITAR_LABEL=$(echo "$LABELS" | grep -i '"editar"' || true)
  HAS_DELETED_LABEL=$(echo "$LABELS" | grep -i '"deleted"' || true)
  HAS_GERENCIA_LABEL=$(echo "$LABELS" | grep -i '"action-gerencia-blog"' || true)

  ENTITY_TYPE="post"
  PREFIX="postid"
  DIR_NAME="post"

  if [[ -n "$HAS_EVENTO_LABEL" || "$LABEL_NAME" == "evento" ]]; then
    ENTITY_TYPE="evento"
    PREFIX="eventid"
    DIR_NAME="evento"
  elif [[ -n "$HAS_NOTE_LABEL" || "$LABEL_NAME" == "note" ]]; then
    ENTITY_TYPE="note"
    PREFIX="noteid"
    DIR_NAME="note"
  fi

  FILE_PATH="src/content/${DIR_NAME}/${PREFIX}-${ISSUE_NUMBER}.md"
  OPERATION=""
}

determine_operation() {
  if [[ "$ACTION_TYPE" == "deleted" ]] || [[ "$ACTION_TYPE" == "closed" && "$STATE_REASON" == "not_planned" ]] || [[ "$ACTION_TYPE" == "unlabeled" && ( "$LABEL_NAME" == "post" || "$LABEL_NAME" == "evento" || "$LABEL_NAME" == "note" ) ]] || [[ "$ACTION_TYPE" == "created" && "$COMMENT_BODY" == *'$rm'* ]] || [[ "$ACTION_TYPE" == "labeled" && ( "$LABEL_NAME" == "exclusao" || "$LABEL_NAME" == "delete" ) ]]; then
    OPERATION="deletar"
    return
  fi

  if [[ "$ACTION_TYPE" == "closed" && "$STATE_REASON" == "completed" ]] || [[ "$ACTION_TYPE" == "opened" && ( -n "$HAS_POST_LABEL" || -n "$HAS_EVENTO_LABEL" || -n "$HAS_NOTE_LABEL" ) ]] || [[ "$ACTION_TYPE" == "labeled" && ( "$LABEL_NAME" == "post" || "$LABEL_NAME" == "evento" || "$LABEL_NAME" == "note" ) ]]; then
    OPERATION="postar"
    return
  fi

  if [[ "$ACTION_TYPE" == "reopened" ]] || [[ "$ACTION_TYPE" == "labeled" && "$LABEL_NAME" == "editar" ]] || [[ "$ACTION_TYPE" == "edited" && (-n "$HAS_POST_LABEL" || -n "$HAS_EVENTO_LABEL" || -n "$HAS_NOTE_LABEL" || -n "$HAS_EDITAR_LABEL" || (-n "$HAS_DELETED_LABEL" && -n "$HAS_GERENCIA_LABEL")) ]]; then
    OPERATION="editar"
    return
  fi

  echo "Nenhuma ação mapeada para este fluxo. Ignorando."
  exit 0 
}

update_github_issue() {
  if [[ "$ACTION_TYPE" == "deleted" ]]; then
    return
  fi

  case "$OPERATION" in
    deletar)
      gh issue comment "$ISSUE_NUMBER" --body "⏳ Excluindo ${ENTITY_TYPE}..." || true
      gh issue edit "$ISSUE_NUMBER" --add-label "deleted,action-gerencia-blog" --remove-label "post,evento,note,editar,arquivado,exclusao,delete,publicado" || true
      ;;
    postar)
      gh issue edit "$ISSUE_NUMBER" --add-label "${ENTITY_TYPE},action-gerencia-blog" --remove-label "editar,deleted,arquivado,exclusao,delete" || true
      ;;
    editar)
      gh issue reopen "$ISSUE_NUMBER" || true
      gh issue edit "$ISSUE_NUMBER" --add-label "editar,edited,action-gerencia-blog" --remove-label "deleted,arquivado,exclusao,delete" || true
      ;;
  esac
}

process_file() {
  if [[ "$OPERATION" == "deletar" ]]; then
    git rm --ignore-unmatch "src/content/post/postid-${ISSUE_NUMBER}.md" "src/content/evento/eventid-${ISSUE_NUMBER}.md" "src/content/note/noteid-${ISSUE_NUMBER}.md" 2>/dev/null || true
    rm -f "src/content/post/postid-${ISSUE_NUMBER}.md" "src/content/evento/eventid-${ISSUE_NUMBER}.md" "src/content/note/noteid-${ISSUE_NUMBER}.md"
    return
  fi

  # Move o evento antigo para a nova pasta caso ele seja editado
  if [[ "$ENTITY_TYPE" == "evento" ]]; then
    git rm "src/content/post/eventid-${ISSUE_NUMBER}.md" 2>/dev/null || true
  elif [[ "$ENTITY_TYPE" == "note" ]]; then
    git rm "src/content/post/noteid-${ISSUE_NUMBER}.md" 2>/dev/null || true
  fi

  mkdir -p "src/content/${DIR_NAME}"
  SAFE_TITLE="${ISSUE_TITLE//\"/\\\"}"
  
  EXTRACTED_TAGS=$(printf "%s\n" "$ISSUE_BODY" | grep -o -E '(^|[[:space:]])#[a-zA-Z0-9_-]+' | tr -d ' #\r' | awk 'NF {print "\""$0"\""}' | paste -sd, -)
  
  if [[ "$ENTITY_TYPE" == "evento" ]] || [[ "$ENTITY_TYPE" == "note" ]]; then
    if [[ -z "$EXTRACTED_TAGS" ]]; then
      EXTRACTED_TAGS="\"$ENTITY_TYPE\""
    fi
    if [[ "$EXTRACTED_TAGS" != *"\"$ENTITY_TYPE\""* ]]; then
      EXTRACTED_TAGS="\"$ENTITY_TYPE\",${EXTRACTED_TAGS}"
    fi
  fi

  if [ -z "$EXTRACTED_TAGS" ]; then
    TAGS_ARRAY="[]"
  else
    TAGS_ARRAY="[${EXTRACTED_TAGS}]"
  fi
  
  CLEAN_BODY=$(printf "%s\n" "$ISSUE_BODY" | sed -E 's/(^|[[:space:]])#[a-zA-Z0-9_-]+//g')
  
  PROCESSED_BODY=$(printf "%s\n" "$CLEAN_BODY" | sed -E 's@\$youtube\(https://www\.youtube\.com/watch\?v=([^)&]+)[^)]*\)@\$youtube(https://www.youtube.com/embed/\1)@g')
  PROCESSED_BODY=$(printf "%s\n" "$PROCESSED_BODY" | sed -E 's@\$youtube\(https://youtu\.be/([^)?]+)[^)]*\)@\$youtube(https://www.youtube.com/embed/\1)@g')
  PROCESSED_BODY=$(printf "%s\n" "$PROCESSED_BODY" | sed -E 's@\$youtube\(([^)]+)\)@<iframe width="100%" height="315" src="\1" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>@g')

  PROCESSED_BODY=$(printf "%s\n" "$PROCESSED_BODY" | sed -E 's@\$spotify\(https://open\.spotify\.com/(track|album|playlist|artist|show|episode)/([^?)]+)[^)]*\)@\$spotify(https://open.spotify.com/embed/\1/\2)@g')
  PROCESSED_BODY=$(printf "%s\n" "$PROCESSED_BODY" | sed -E 's@\$spotify\(([^)]+)\)@<iframe style="border-radius:12px" src="\1" width="100%" height="352" frameborder="0" allowfullscreen="" allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture" loading="lazy"></iframe>@g')
  
  DESC_SOURCE=$(printf "%s\n" "$CLEAN_BODY" | sed -E 's/\$(youtube|spotify)\([^)]+\)//g')
  POST_DESCRIPTION=$(printf "%s" "$DESC_SOURCE" | tr '\n' ' ' | tr '\r' ' ' | sed 's/"/\\"/g' | cut -c 1-140)

  {
    echo "---"
    if [[ "$ENTITY_TYPE" != "note" ]]; then
      echo "title: \"${SAFE_TITLE}\""
    fi
    echo "description: \"${POST_DESCRIPTION}...\""
    echo "publishDate: \"${ISSUE_DATE}\""
    echo "tags: ${TAGS_ARRAY}"
    echo "---"
    echo ""
    printf "%s\n" "$PROCESSED_BODY"
  } > "$FILE_PATH"
}

commit_and_deploy() {
  git config --global user.name "github-actions[bot]"
  git config --global user.email "github-actions[bot]@users.noreply.github.com"
  git config --global pull.rebase true

  if [[ "$OPERATION" != "deletar" ]]; then
    git add "$FILE_PATH"
  fi

  if git diff-index --quiet HEAD; then
    echo "O conteúdo é idêntico. Nenhuma mudança para comitar."
    exit 0
  fi

  git commit -m "chore: $OPERATION $ENTITY_TYPE gerado pela issue #${ISSUE_NUMBER}"
  git pull origin "$(git branch --show-current)"
  git push
  
  if [[ "$ACTION_TYPE" == "deleted" ]]; then
    gh workflow run deploy.yml -f operation="$OPERATION" -f entity_type="$ENTITY_TYPE"
  else
    gh workflow run deploy.yml -f issue_number="$ISSUE_NUMBER" -f operation="$OPERATION" -f entity_type="$ENTITY_TYPE"
  fi
}

close_issue_if_completed() {
  if [[ "$ACTION_TYPE" == "deleted" ]]; then
    return
  fi

  ISSUE_STATE=$(gh issue view $ISSUE_NUMBER --json state -q .state || echo "CLOSED")
  if [[ "$ISSUE_STATE" == "OPEN" ]]; then
    gh issue comment $ISSUE_NUMBER --body "⏳ A issue será fechada em 1 minuto..." || true
    sleep 60
    gh issue close $ISSUE_NUMBER --reason "completed" || true
  fi
}

check_authorization
setup_variables
determine_operation
update_github_issue
process_file
commit_and_deploy
close_issue_if_completed
