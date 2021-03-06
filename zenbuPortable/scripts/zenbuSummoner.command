#!/usr/bin/env bash
#
# 【 zenbuPortable 】 zenbuSummoner.command
#   Ver1.40.190419a
# Concepted by TANAHASHI, Jiro (aka jtFuruhata)
# Copyright (C) 2019 jtLab, Hokkaido Information University
#
summoner_usage () {
    echo "Usage:"
    echo "  . zenbuSummoner.command [<id>]"
    echo "  [.] zenbuSummoner.command [-k] [-r]"
    echo
    echo "Description:"
    echo "  zenbuPortable SSH agent summoner/recaller"
    echo
    echo "Options:"
    echo "  -k ... Unset key & Recall agent (only for Windows)"
    echo "         Unset all keys when exec without ."
    echo "  -r ... Unset key & Recall **ALL** agents (only for Windows)"
    echo "         Unset all keys when exec without ."
    echo "  <id> ... Use specific identity instead of .ssh/ssh_id"
    exit 1
}
summoner_optKill=0
summoner_optRecall=0
while getopts "kr" options
do
    case $options in
        k)  # Recall agent
            summoner_optKill=1
            ;;
        r)  # Recall all agents
            summoner_optRecall=1
            ;;
    esac
done
shift $((OPTIND - 1))
summoner_optID="$1"

unset SSH_KEY
summoner_result=0

addkey () {
    ssh-add $SSH_KEY
}

rmkey () {
    ssh-add -d $SSH_KEY
}

export -f addkey
export -f rmkey

echo "zenbuSummoner is recognizing status about SSH & Git"
echo

#
# include zenbuEnv and portaleGitPortal if necessary
if [ -z "$zenbuOSType" ]; then
    export dontSummonMe=true
    . `dirname $0`/zenbuEnv.sh;
    unset dontSummonMe
fi

#
# check Git & SSH agent installation
which git       > /dev/null 2>&1;   summoner_check_git=$?
which ssh-agent > /dev/null 2>&1;   summoner_check_ssh_agent=$?
which ssh-add   > /dev/null 2>&1;   summoner_check_ssh_add=$?
#
## check SSH agent status
[ -z $SSH_AGENT_PID ];   summoner_check_PID=$?
[ -z $SSH_AUTH_SOCK ];   summoner_check_SOCK=$?

#
## preparing SSH envs
if [ $(($summoner_check_ssh_agent+$summoner_check_ssh_add)) = 0 ]; then
    export SSH_HOME="$HOME/.ssh"
    export SSH_KEYS="$Tzenbu/.ssh"
    mkdir -p "$SSH_KEYS"

    if [ $(($summoner_optRecall+$summoner_optKill)) = 0 ]; then
        ## check $SSH_HOME/ssh_id
        if [ ! -z $summoner_optID ]; then
            export SSH_ID="$summoner_optID"
            echo "OpenSSH(Git) will attempt to use <id>: $SSH_ID"
        elif [ -e "$SSH_HOME/ssh_id" ]; then
            export SSH_ID="`cat $SSH_HOME/ssh_id`"
            echo "OpenSSH(Git) will attempt to use ssh_id: $SSH_ID"
        else
            echo "No Key Mode"
            unset SSH_ID
        fi

        if [ ! -z $SSH_ID ]; then
            if [ -e "$SSH_HOME/$SSH_ID" ]; then
                export SSH_KEY="$SSH_KEYS/$SSH_ID"
                cp -f "$SSH_HOME/$SSH_ID" "$SSH_KEY"
                chmod 700 "$SSH_KEY" > /dev/null 2>&1
                if [ $? = 1 ]; then
                    echo "** WARNING **"
                    echo "Unable to chmod: check filesystem."
                    unset SSH_ID
                    unset SSH_KEY
                    summoner_result=1
                fi
            else
                echo "** WARNING **"
                echo "  Missing ID file $SSH_ID: turn into No Key Mode"
                unset SSH_ID
                summoner_result=1
            fi
        fi

        ## preparing placeholder
        if [ ! -e "$SSH_HOME/known_hosts" ]; then
            touch "$SSH_HOME/known_hosts";
        fi
        if [ ! -e "$SSH_HOME/config" ]; then
            touch "$SSH_HOME/config";
        fi

        ## check git config
        if [ $summoner_check_git = 0 ]; then
            git config --global core.sshCommand "ssh -T -o UserKnownHostsFile=$SSH_HOME/known_hosts -F $SSH_HOME/config -i $SSH_KEY"
            git config --global init.templatedir "$zenbuPathGit/share/git-core/templates"
            git config --global core.autoCRLF false
            summoner_gitname=`git config --global user.name`
            summoner_check_gitname=$?
            echo "Git user.name  = $summoner_gitname"
            summoner_gitemail=`git config --global user.email`
            summoner_check_gitemail=$?
            echo "Git user.email = $summoner_gitemail"
            if [ $(($summoner_check_gitname+$summoner_check_gitemail)) -gt 0 ]; then
                echo "Notice: You shoud set up your name & email for Git:"
                echo "  git config --global user.name \"Taro Yamada\""
                echo "  git config --global user.email \"tyamada@mygitid.info\""
            fi
        else
            echo "** WARNING **"
            echo "  Missing Git: we can't use Git."
            summoner_result=1
        fi

        ## summon agent if necessary
        ssh-add -l > /dev/null 2>&1
        summoner_ssh_add_l=$?
        # Could not open a connection -> summon agent
        if [ $summoner_ssh_add_l = 2 ]; then
            unset SSH_AGENT_PID
            unset SSH_AUTH_SOCK
            echo "Now Summoning SSH agent..." 
            eval $(echo "$(ssh-agent)")
        else
            echo "SSH agent is already standing by you."
        fi
    # unset key & recall all agent (for windows)
    else
        if [ -z $SSK_KEY ]; then
            ssh-add -D
        else
            ssh-add -d $SSH_KEY
            rm -f $SSH_KEY
            unset SSH_KEY
        fi
        if [ $zenbuOSType == "win" ]; then
            if [ $summoner_optRecall = 1 ]; then
                ssh-recall-all
            else
                eval $(echo "$(ssh-agent -k)")
            fi
            unset SSH_AGENT_PID
            unset SSH_AUTH_SOCK
        fi
    fi

    # key list
    summoner_list="`ssh-add -l`"
    if [ $? = 0 ]; then
        echo "SSH agent key list:"
        echo "$summoner_list"
    else
        echo "SSH agent has no key."
    fi
else
    echo "** WARNING **"
    echo "  Missing OpenSSH: zenbuSummoner can't summon SSH agent."
    summoner_result=1
fi

if [ ! -z $SSH_KEY ]; then
    echo
    echo "You may use 'addkey' and 'rmkey' command for SSH key operation."  
    echo
fi

return $summoner_result > /dev/null 2>&1
if [ $? = 1 ]; then
    exit $summoner_result
fi