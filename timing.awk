#!/bin/awk
func getSeconds(time) {
    hour=substr(time,0,2)
    min=substr(time,4,2)
    sec=substr(time,7,2)
    return hour*3600+min*60+sec
}

BEGIN {
    DEPLOY_POD="che-1-deploy"
    MARKER_PVC_BOUND_START="Creating volume for PVC \"claim-che-workspace\""
    MARKER_PVC_BOUND_END="claim \"../claim-che-workspace\" entered phase \"Bound\""
    
    MARKER_PV="volume [^ ]* bound to claim \"../che-data-volume\""
    
    MARKER_POD_SCHEDULED="type: 'Normal' reason: 'SuccessfulCreate' Created pod: che-1"
    
    MARKER_ATTACH_START_PREFIX="attacherDetacher.AttachVolume started for volume "
    MARKER_ATTACH_END_PREFIX="AttachVolume.Attach succeeded for volume "

    MARKER_ATTACH_START="attacherDetacher.AttachVolume started for volume PV"
    MARKER_ATTACH_END="AttachVolume.Attach succeeded for volume PV"

    MARKER_SCHEDULED="type: 'Normal' reason: 'Scheduled' Successfully assigned che-1"
    
    MARKER_BEGIN=MARKER_PVC_BOUND_START
#    print "Process", "Start", "End"
    cmd="kubectl get events  --sort-by='.metadata.creationTimestamp'  -o 'go-template={{range .items}}{{if eq .involvedObject.kind \"Pod\"}}{{if eq .reason \"Started\"}}{{.involvedObject.name}} {{.metadata.creationTimestamp}}{{\"\\n\"}}{{end}}{{end}}{{end}}'"
    while ( ( cmd | getline result ) > 0 ) {
        split(result, a, " ")
        pods_started[a[1]]=a[2]
    } 
    close(cmd)
    cmd="kubectl get events  --sort-by='.metadata.creationTimestamp'  -o 'go-template={{range .items}}{{if eq .involvedObject.kind \"Pod\"}}{{if eq .reason \"Scheduled\"}}{{.involvedObject.name}} {{.metadata.creationTimestamp}}{{\"\\n\"}}{{end}}{{end}}{{end}}'"
    while ( ( cmd | getline result ) > 0 ) {
        split(result, a, " ")
        pods_scheduled[a[1]]=a[2]
    } 
    close(cmd)
}
{
    if ( $0 ~ MARKER_SCHEDULED) {
            pod=$(NF-2)
            if (pod != DEPLOY_POD) {
                    for (p in pods_started) {
                       if (p == pod) {
                           pod_begin_time=substr(pods_scheduled[p],12,8)
                           pod_end_time=substr(pods_started[p],12,8)
                           pod_time=getSeconds(pod_end_time) - getSeconds(pod_begin_time)
                           print "Pod-"pod, pod_begin_time, pod_end_time, pod_time
                       }
                    }
            }
    }

    if ( $0 ~ MARKER_BEGIN) {
            begin_time=$3
    }
    if ( $0 ~ MARKER_PVC_BOUND_START) {
            pvc_begin_time=$3
    }
    if ( $0 ~ MARKER_PVC_BOUND_END) {
            pvc_end_time=$3
            print "\n"
            pvc_time=getSeconds(pvc_end_time) - getSeconds(pvc_begin_time)
            print "PVC",  pvc_begin_time, pvc_end_time, pvc_time
    }

    if ( $0 ~ MARKER_PV) {
           PV=$(NF-4)
           MARKER_ATTACH_START=MARKER_ATTACH_START_PREFIX  PV
           MARKER_ATTACH_END=MARKER_ATTACH_END_PREFIX  PV
    }

    if ( $0 ~ MARKER_ATTACH_START) {
            attach_begin_time=$3
    }
    if ( $0 ~ MARKER_ATTACH_END) {
            attach_end_time=$3
            attach_time=getSeconds(attach_end_time) - getSeconds(attach_begin_time)
            total_time=getSeconds(pod_end_time) - getSeconds(pvc_begin_time) - getSeconds("04:00:00")
            print "Attach",  attach_begin_time, attach_end_time, attach_time
            print "Total", total_time
            print "Summary", total_time, pod_time, attach_time, pvc_time
    }
}
