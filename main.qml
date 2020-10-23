import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import Qt.labs.settings 1.0
import QSyncable 1.0
import SortFilterProxyModel 0.2

ApplicationWindow {
    id: root

    width: 640
    height: 480
    visible: true
    title: qsTr("YounHacktoberFest")

    property string github_token
    onGithub_tokenChanged: updateParticipants()
    Settings {
        property alias github_token: root.github_token
    }

    readonly property string participantsUrl: "https://raw.githubusercontent.com/Younup/Hacktoberfest/master/2020/participants.json"
    property var participants: []

    function updateParticipants() {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                root.participants = JSON.parse(xhr.responseText);
        };

        xhr.open("GET", root.participantsUrl, true);
        xhr.send();
    }

    //Component.onCompleted: updateParticipants()

    JsonListModel {
        id: participantsModel
        source: root.participants
        keyField: "github_username"
    }

    ListView {
        id: listView
        anchors.fill: parent
        model: participantsModel
        delegate: ItemDelegate {
            id: participantDelegate
            width: listView.width
            required property string name
            required property string github_username
            property var github_info
            text: name
            rightPadding: prCountLabel.width
            Label {
                id: prCountLabel
                visible: !!participantDelegate.github_info
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                verticalAlignment: Text.AlignVCenter
                padding: 8

                text: pullRequestsProxyModel.count + " PR"
            }

            JsonListModel {
                id: pullRequestsModel
                source: participantDelegate.github_info ? participantDelegate.github_info.data.user.pullRequests.nodes : []
                keyField: "id"
            }

            SortFilterProxyModel {
                id: pullRequestsProxyModel
                sourceModel: pullRequestsModel
                filters: RangeFilter {
                    roleName: "createdAt"
                    minimumInclusive: true
                    minimumValue: "2020-10-01T00:00:00Z"
                }
            }

            function updateInfo() {
                let xhr = new XMLHttpRequest();
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                        github_info = JSON.parse(xhr.responseText);
                    else
                        print(xhr.responseText);
                };

                const payload = {
                    operationName: "userWithPRs",
                    query: root.participantInfoQuery,
                    variables: { userLogin: github_username }
                };

                xhr.open("POST", "https://api.github.com/graphql", true);
                xhr.setRequestHeader('Authorization', 'bearer ' + root.github_token );
                xhr.send(JSON.stringify(payload));
            }

            Component.onCompleted: updateInfo()
        }
    }

    footer: Pane {
        Material.elevation: 1
        Material.background: Material.primary
        contentItem: TextField {
            placeholderText: "Token Github"
            inputMethodHints: TextInput.Password
            selectByMouse: true
            text: root.github_token
            onTextEdited: root.github_token = text
        }
    }

    readonly property string participantInfoQuery: `
query userWithPRs($userLogin: String!){
  user(login:$userLogin) {
    ...userFields
  }
}

fragment userFields on User {
  login
  avatarUrl
  pullRequests(first: 100, orderBy:{field:CREATED_AT, direction:DESC}) {
    totalCount
    nodes {
      id
      title
      createdAt
      url
      repository {
        nameWithOwner
        repositoryTopics(first: 10) {
          nodes {
            topic {
              name
            }
          }
        }
      }
      labels(first:100) {
        nodes {
          name
        }
      }
      author {
        login
      }
    }
  }
}
`
}
