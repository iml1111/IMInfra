# HorizontalPodAutoscaler 문법 정리

## autoscaling/v1

### metadata

하도 많이 다뤄서 스킵, 다른 문서 참고합시다.

### spec

- minReplicas: 스케일 다운이 일어날때 최소 하한 (디폴트: 1)
- maxReplcas: 스케일 아웃이 일어날떄 최대 상한
- scaleTargetRef: 스케일링 참조 타겟 (해당 참조 타겟에 대한 정보 일부분, 메타데이터를 그대로 쓰면 됨)
  - apiVersion: apps/v1 등
  - kind: Deployment 등
  - name: 디플로이먼트 이름 등
- targetCPUUtilizationPercentage: 목표 평균 CPU 사용률 (%), 지정되지 않으면 알아서 함.



# References

- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v1/

