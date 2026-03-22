#!/bin/bash
set -e

HAS_POST_LABEL=$(echo "$LABELS" | grep -i '"post"' || true)
HAS_EVENTO_LABEL=$(echo "$LABELS" | grep -i '"evento"' || true)
HAS_EDITAR_LABEL=$(echo "$LABELS" | grep -i '"editar"' || true)
HAS_DELETED_LABEL=$(echo "$LABELS" | grep -i '"deleted"' || true)
HAS_GERENCIA_LABEL=$(echo "$LABELS" | grep -i '"action-gerencia-blog"' || true)

# Define o tipo de entidade com base na tag atual
ENTITY_TYPE="post"
if [[ -n "$HAS_EVENTO_LABEL" || "$LABEL_NAME" == "evento" ]]; then
  ENTITY_TYPE="evento"
fi

if [[ "$ENTITY_TYPE" == "evento" ]]; then
  PREFIX="eventid"
else
  PREFIX="postid"
fi

FILE_PATH="src/content/post/${PREFIX}-${ISSUE_NUMBER}.md"
OPERATION=""

if [[ "$ACTION_TYPE" == "deleted" ]] || [[ "$ACTION_TYPE" == "closed" && "$STATE_REASON" == "not_planned" ]] || [[ "$ACTION_TYPE" == "unlabeled" && ( "$LABEL_NAME" == "post" || "$LABEL_NAME" == "evento" ) ]] || [[ "$ACTION_TYPE" == "created" && "$COMMENT_BODY" == *'$rm'* ]] || [[ "$ACTION_TYPE" == "labeled" && ( "$LABEL_NAME" == "exclusao" || "$LABEL_NAME" == "delete" ) ]]; then
  OPERATION="deletar"
elif [[ "$ACTION_TYPE" == "closed" && "$STATE_REASON" == "completed" ]] || [[ "$ACTION_TYPE" == "opened" && ( -n "$HAS_POST_LABEL" || -n "$HAS_EVENTO_LABEL" ) ]] || [[ "$ACTION_TYPE" == "labeled" && ( "$LABEL_NAME" == "post" || "$LABEL_NAME" == "evento" ) ]]; then
  OPERATION="postar"
elif [[ "$ACTION_TYPE" == "reopened" ]] || [[ "$ACTION_TYPE" == "labeled" && "$LABEL_NAME" == "editar" ]] || [[ "$ACTION_TYPE" == "edited" && (-n "$HAS_POST_LABEL" || -n "$HAS_EVENTO_LABEL" || -n "$HAS_EDITAR_LABEL" || (-n "$HAS_DELETED_LABEL" && -n "$HAS_GERENCIA_LABEL")) ]]; then
  OPERATION="editar"
else
  echo "Nenhuma ação mapeada para este fluxo. Ignorando."
  exit 0
fi

if [[ "$OPERATION" == "deletar" && "$ACTION_TYPE" != "deleted" ]]; then
  gh issue comment $ISSUE_NUMBER --body "⏳ Excluindo ${ENTITY_TYPE}..." || true
fi

if [[ "$ACTION_TYPE" != "deleted" ]]; then
  if [[ "$OPERATION" == "deletar" ]]; then
    gh issue edit $ISSUE_NUMBER --add-label "deleted,action-gerencia-blog" --remove-label "post,evento,editar,arquivado,exclusao,delete,publicado" || true
  elif [[ "$OPERATION" == "postar" ]]; then
    gh issue edit $ISSUE_NUMBER --add-label "${ENTITY_TYPE},action-gerencia-blog" --remove-label "editar,deleted,arquivado,exclusao,delete" || true
  elif [[ "$OPERATION" == "editar" ]]; then
    gh issue reopen $ISSUE_NUMBER || true
    gh issue edit $ISSUE_NUMBER --add-label "editar,edited,action-gerencia-blog" --remove-label "deleted,arquivado,exclusao,delete" || true
  fi
fi

if [[ "$OPERATION" == "deletar" ]]; then
  git rm --ignore-unmatch "src/content/post/postid-${ISSUE_NUMBER}.md" "src/content/post/eventid-${ISSUE_NUMBER}.md" 2>/dev/null || true
  rm -f "src/content/post/postid-${ISSUE_NUMBER}.md" "src/content/post/eventid-${ISSUE_NUMBER}.md"
else
  mkdir -p src/content/post
  SAFE_TITLE="${ISSUE_TITLE//\"/\\\"}"
  
  EXTRACTED_TAGS=$(printf "%s\n" "$ISSUE_BODY" | grep -o -E '(^|[[:space:]])#[a-zA-Z0-9_-]+' | tr -d ' #\r' | awk 'NF {print "\""$0"\""}' | paste -sd, -)
  
  if [[ "$ENTITY_TYPE" == "evento" ]]; then
    if [ -z "$EXTRACTED_TAGS" ]; then
      EXTRACTED_TAGS="\"evento\""
    elif [[ "$EXTRACTED_TAGS" != *"\"evento\""* ]]; then
      EXTRACTED_TAGS="\"evento\",${EXTRACTED_TAGS}"
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
    echo "title: \"${SAFE_TITLE}\""
    echo "description: \"${POST_DESCRIPTION}...\""
    echo "publishDate: \"${ISSUE_DATE}\""
    echo "tags: ${TAGS_ARRAY}"
    echo "---"
    echo ""
    printf "%s\n" "$PROCESSED_BODY"
  } > "$FILE_PATH"
fi

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global pull.rebase true

if [[ "$OPERATION" != "deletar" ]]; then
  git add "$FILE_PATH"
fi

if ! git diff-index --quiet HEAD; then
  git commit -m "chore: $OPERATION $ENTITY_TYPE gerado pela issue #${ISSUE_NUMBER}"
  git pull origin $(git branch --show-current)
  git push
  
  if [[ "$ACTION_TYPE" == "deleted" ]]; then
    gh workflow run deploy.yml -f operation=$OPERATION -f entity_type=$ENTITY_TYPE
  else
    gh workflow run deploy.yml -f issue_number=$ISSUE_NUMBER -f operation=$OPERATION -f entity_type=$ENTITY_TYPE
  fi
else
  echo "O conteúdo é idêntico. Nenhuma mudança para comitar."
  exit 0
fi

if [[ "$ACTION_TYPE" != "deleted" ]]; then
  ISSUE_STATE=$(gh issue view $ISSUE_NUMBER --json state -q .state || echo "CLOSED")
  if [[ "$ISSUE_STATE" == "OPEN" ]]; then
    gh issue comment $ISSUE_NUMBER --body "⏳ A issue será fechada em 1 minuto..." || true
    sleep 60
    gh issue close $ISSUE_NUMBER --reason "completed" || true
  fi
fi
