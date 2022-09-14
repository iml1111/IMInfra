# Service 문법 정리

## Nodeport

### [metadata](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta)
디플로이먼트와 작성 방식은 거의 동일함. 해당 문서 참고.

### [spec](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/#ServiceSpec)

- selector: map 형태의 string으로 입력받음. pod에 대한 labels 데이터로 식별하여 범주를 식별함.
- [type](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types): Nodeport

- ports []: 포트 관련 정보를 복수로 입력받을 수 있음.
  - protocol: "TCP", "UDP", and "SCTP". Default is TCP.
  - nodePort: Nodeport 혹은 LoadBalancer일때 외부에 노출되는 포트를 의미.
  - port: 서비스가 클러스터 내부에서 노출되는 포트를 의미.
  - targetPort: 서비스가 해당 포드에 액세스할 포트


# References
https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/

