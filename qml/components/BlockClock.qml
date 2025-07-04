// Copyright (c) 2023 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0

import org.bitcoincore.qt 1.0

import "../controls"
import "../controls/utils.js" as Utils

Item {
    id: root
    property real parentWidth: 600
    property real parentHeight: 600
    property bool showNetworkIndicator: true

    width: dial.width
    height: dial.height + networkIndicator.height + networkIndicator.anchors.topMargin

    property alias header: mainText.text
    property alias subText: subText.text
    property int headerSize: 32
    property bool connected: nodeModel.numOutboundPeers > 0
    property bool synced: nodeModel.verificationProgress > 0.999
    property string syncProgress: formatProgressPercentage(nodeModel.verificationProgress * 100)
    property bool paused: false
    property var syncState: Utils.formatRemainingSyncTime(nodeModel.remainingSyncTime)
    property string syncTime: syncState.text
    property bool estimating: syncState.estimating
    property bool faulted: nodeModel.faulted

    activeFocusOnTab: true

    Settings {
        id: settings
        property alias blockclocksize: dial.scale
    }

    BlockClockDial {
        id: dial
        anchors.horizontalCenter: root.horizontalCenter
        scale: Theme.blockclocksize
        width: {Math.max(Math.min(200, Math.min(root.parentWidth - 30, root.parentHeight - 30)), 
                Math.min((root.parentWidth * dial.scale), (root.parentHeight * dial.scale)))}
        height: dial.width
        penWidth: dial.width / 50
        timeRatioList: chainModel.timeRatioList
        verificationProgress: nodeModel.verificationProgress
        paused: root.paused || root.faulted
        connected: root.connected
        synced: nodeModel.verificationProgress > 0.999
        backgroundColor: Theme.color.neutral2
        timeTickColor: Theme.color.neutral5
        confirmationColors: Theme.color.confirmationColors

        Behavior on backgroundColor {
            ColorAnimation { duration: 150 }
        }

        Behavior on timeTickColor {
            ColorAnimation { duration: 150 }
        }

        Behavior on confirmationColors {
            ColorAnimation { duration: 150 }
        }
    }

    Icon {
        id: bitcoinIcon
        source: "image://images/bitcoin-circle"
        color: Theme.color.neutral9
        size: Math.max(dial.width / 5, 1)
        anchors.bottom: mainText.top
        anchors.horizontalCenter: root.horizontalCenter
    }

    Label {
        id: mainText
        anchors.centerIn: dial
        font.family: "Inter"
        font.styleName: "Semi Bold"
        font.pixelSize: dial.width * (4/25)
        color: Theme.color.neutral9

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    Label {
        id: subText
        anchors.top: mainText.bottom
        property bool estimating: root.estimating
        anchors.horizontalCenter: root.horizontalCenter
        font.family: "Inter"
        font.styleName: "Semi Bold"
        font.pixelSize: dial.width * (9/100)
        color: Theme.color.neutral4

        Component.onCompleted: {
            colorChanged.connect(function() {
                if (!subText.estimating) {
                    themeChange.restart();
                }
            });

            estimatingChanged.connect(function() {
                if (subText.estimating) {
                    estimatingTime.start();
                } else {
                    estimatingTime.stop();
                }
            });

            subText.estimatingChanged(subText.estimating);
        }

        ColorAnimation on color{
            id: themeChange
            target: subText
            duration: 150
        }

        SequentialAnimation {
            id: estimatingTime
            loops: Animation.Infinite
            ColorAnimation { target: subText; property: "color"; from: subText.color; to: Theme.color.neutral6; duration: 1000 }
            ColorAnimation { target: subText; property: "color"; from: Theme.color.neutral6; to: subText.color; duration: 1000 }
        }

    }

    PeersIndicator {
        anchors.top: subText.bottom
        anchors.topMargin: dial.width / 10
        anchors.horizontalCenter: root.horizontalCenter
        numOutboundPeers: nodeModel.numOutboundPeers
        maxNumOutboundPeers: nodeModel.maxNumOutboundPeers
        indicatorDimensions: dial.width * (3/200)
        indicatorSpacing: dial.width / 40
        paused: root.paused || root.faulted
    }

    NetworkIndicator {
        id: networkIndicator
        show: root.showNetworkIndicator
        anchors.top: dial.bottom
        anchors.topMargin: networkIndicator.visible ? 30 : 0
        anchors.horizontalCenter: root.horizontalCenter
    }

    MouseArea {
        anchors.fill: dial
        cursorShape: root.faulted ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !root.faulted
        onClicked: {
            if (!root.faulted) {
                root.paused = !root.paused
                nodeModel.pause = root.paused
            }
        }
        FocusBorder {
            visible: root.activeFocus
        }
    }

    states: [
        State {
            name: "IBD"; when: !synced && !paused && connected
            PropertyChanges {
                target: root
                header: root.syncProgress
                subText: root.syncTime
            }
        },

        State {
            name: "BLOCKCLOCK"; when: synced && !paused && connected
            PropertyChanges {
                target: root
                header: Number(nodeModel.blockTipHeight).toLocaleString(Qt.locale(), 'f', 0)
                subText: "Blocktime"
                estimating: false
            }
        },

        State {
            name: "PAUSE"; when: paused && !faulted
            PropertyChanges {
                target: root
                header: "Paused"
                headerSize: dial.width * (3/25)
                subText: "Tap to resume"
                estimating: false
            }
            PropertyChanges {
                target: bitcoinIcon
                anchors.bottomMargin: dial.width / 40
            }
            PropertyChanges {
                target: subText
                anchors.topMargin: dial.width / 50
            }
        },

        State {
            name: "ERROR"; when: faulted
            PropertyChanges {
                target: root
                header: "Error"
                headerSize: dial.width * (3/25)
            }
            PropertyChanges {
                target: bitcoinIcon
                anchors.bottomMargin: dial.width / 40
                icon.source: "image://images/error"
            }
        },

        State {
            name: "CONNECTING"; when: !paused && !connected
            PropertyChanges {
                target: root
                header: "Connecting"
                headerSize: dial.width * (3/25)
                subText: "Please wait"
                estimating: false
            }
            PropertyChanges {
                target: bitcoinIcon
                anchors.bottomMargin: dial.width / 40
            }
            PropertyChanges {
                target: subText
                anchors.topMargin: dial.width / 50
            }
        }
    ]


    function formatProgressPercentage(progress) {
        if (progress >= 1) {
            return Math.round(progress) + "%"
        } else if (progress >= 0.1) {
            return progress.toFixed(1) + "%"
        } else if (progress >= 0.01) {
            return progress.toFixed(2) + "%"
        } else {
            return "0%"
        }
    }
}
